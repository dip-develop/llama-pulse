import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../domain/runtime/runtime_failure.dart';

/// Extracts a pinned llama.cpp archive into a staging directory.
///
/// Everything is streamed through file-backed archive streams: a `.tar.gz` is
/// gunzipped and read as it is decoded, and a `.zip` is read through its
/// central directory with random access. No archive is ever held in memory
/// whole, because the CUDA runtime archives reach several hundred megabytes
/// and expand past a gigabyte.
///
/// The extractor is deliberately strict. It accepts one top-level directory
/// (upstream names it `llama-<build>/` or `cudart-llama-<build>-.../`), strips
/// it, and rejects absolute paths, drive letters, `..`, backslashes, duplicate
/// entries, hard links, escaping symlinks, unsupported entry types and
/// archives that exceed the entry or byte limits.
final class ArchiveExtractor {
  /// Creates a stateless extractor.
  const ArchiveExtractor();

  /// Extracts [archive] into [destination] and returns the number of regular
  /// files written.
  ///
  /// [assetName] decides the format: `.tar.gz` and `.tgz` use the tar reader,
  /// `.zip` the zip reader. [maxEntries] and [maxTotalBytes] bound what a
  /// crafted archive can force the process to do.
  Future<int> extract({
    required File archive,
    required String assetName,
    required Directory destination,
    int maxEntries = 2000,
    int maxTotalBytes = 3 * 1024 * 1024 * 1024,
  }) async {
    final lower = assetName.toLowerCase();
    try {
      if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
        return _extractTarGz(
          archive: archive,
          destination: destination,
          maxEntries: maxEntries,
          maxTotalBytes: maxTotalBytes,
        );
      }
      if (lower.endsWith('.zip')) {
        return _extractZip(
          archive: archive,
          destination: destination,
          maxEntries: maxEntries,
          maxTotalBytes: maxTotalBytes,
        );
      }
      throw RuntimeException(
        RuntimeFailureCode.extraction,
        'unsupported archive format: $assetName',
      );
    } on RuntimeException {
      rethrow;
    } on Object catch (error) {
      throw RuntimeException(
        RuntimeFailureCode.extraction,
        'could not extract $assetName: $error',
        cause: error,
      );
    }
  }

  int _extractTarGz({
    required File archive,
    required Directory destination,
    required int maxEntries,
    required int maxTotalBytes,
  }) {
    final fileStream = InputFileStream(archive.path);
    InputStream? tarStream;
    try {
      final decoder = TarDecoder();
      final state = _ExtractionState(
        destination: destination,
        maxEntries: maxEntries,
        maxTotalBytes: maxTotalBytes,
      );
      tarStream = GZipDecoder().decodeLazy(fileStream);
      decoder.decodeStream(
        tarStream,
        storeData: true,
        keepEntries: true,
        callback: (entry) {
          // TarDecoder adds the TarFile before it calls back, and that object
          // still carries the type flag the extracted ArchiveFile drops. It is
          // the only way to tell a hard link from a symbolic link here.
          state.addTarEntry(entry, decoder.files.last);
        },
      );
      state.finish();
      return state.fileCount;
    } finally {
      tarStream?.closeSync();
      fileStream.closeSync();
    }
  }

  int _extractZip({
    required File archive,
    required Directory destination,
    required int maxEntries,
    required int maxTotalBytes,
  }) {
    final input = InputFileStream(archive.path);
    try {
      final decoded = ZipDecoder().decodeStream(input);
      final state = _ExtractionState(
        destination: destination,
        maxEntries: maxEntries,
        maxTotalBytes: maxTotalBytes,
      );
      for (final entry in decoded) {
        state.addZipEntry(entry);
      }
      state.finish();
      return state.fileCount;
    } finally {
      input.closeSync();
    }
  }
}

final class _ExtractionState {
  _ExtractionState({
    required this.destination,
    required this.maxEntries,
    required this.maxTotalBytes,
  });

  final Directory destination;
  final int maxEntries;
  final int maxTotalBytes;

  final Map<String, bool> _seen = <String, bool>{};
  final List<_PendingLink> _links = <_PendingLink>[];
  final Map<int, List<String>> _modes = <int, List<String>>{};
  String? _prefix;
  int _entries = 0;
  int _totalBytes = 0;
  int _fileCount = 0;

  int get fileCount => _fileCount;

  void addTarEntry(ArchiveFile entry, TarFile tarFile) {
    _countEntry(entry.name);
    final type = tarFile.typeFlag;
    if (type == TarFile.hardLink) {
      throw _unsafe('hard link is not allowed: ${entry.name}');
    }
    if (type != '' &&
        type != TarFile.normalFile &&
        type != TarFile.contFile &&
        type != TarFile.directory &&
        type != TarFile.symbolicLink) {
      throw _unsafe('unsupported tar entry type "$type": ${entry.name}');
    }
    _addEntry(entry);
  }

  void addZipEntry(ArchiveFile entry) {
    _countEntry(entry.name);
    final type = entry.mode & 0xf000;
    if (type != 0 && type != 0x8000 && type != 0x4000 && type != 0xa000) {
      throw _unsafe('unsupported zip entry type: ${entry.name}');
    }
    _addEntry(entry);
  }

  void finish() {
    for (final link in _links) {
      _createLink(link);
    }
    _applyPermissions();
  }

  void _countEntry(String name) {
    _entries++;
    if (_entries > maxEntries) {
      throw _unsafe('archive has more than $maxEntries entries (at "$name")');
    }
  }

  void _addEntry(ArchiveFile entry) {
    final isDirectory = entry.isDirectory;
    final segments = _segments(entry.name);
    final stripped = _stripPrefix(segments, entry.name, isDirectory);
    if (stripped.isRoot) {
      if (!isDirectory) {
        throw _unsafe(
          'entry has no path below the archive root: ${entry.name}',
        );
      }
      return;
    }

    final relative = stripped.relative;
    final absolute = p.joinAll(<String>[
      destination.path,
      ...relative.split('/'),
    ]);
    final previous = _seen[relative];
    if (previous != null) {
      if (previous && isDirectory) {
        // Repeating a directory header is harmless; repeating a file is not.
        return;
      }
      throw _unsafe('duplicate archive entry: $relative');
    }
    _seen[relative] = isDirectory;

    if (entry.isSymbolicLink) {
      final target = entry.symbolicLink!;
      _validateLink(relative, target);
      _links.add(_PendingLink(relative: relative, target: target));
      return;
    }

    if (isDirectory) {
      _ensureParent(absolute);
      final type = FileSystemEntity.typeSync(absolute, followLinks: false);
      if (type == FileSystemEntityType.file ||
          type == FileSystemEntityType.link) {
        throw _unsafe('directory entry collides with a file: $relative');
      }
      Directory(absolute).createSync(recursive: true);
      return;
    }

    if (entry.size < 0) {
      throw _unsafe('negative entry size: $relative');
    }
    if (_totalBytes + entry.size > maxTotalBytes) {
      throw _unsafe(
        'archive expands beyond $maxTotalBytes bytes at "$relative"',
      );
    }
    _totalBytes += entry.size;
    _writeFile(entry, relative, absolute);
    _fileCount++;
  }

  List<String> _segments(String rawName) {
    var name = rawName;
    while (name.startsWith('./')) {
      name = name.substring(2);
    }
    if (name.isEmpty) {
      throw _unsafe('empty archive entry name');
    }
    if (name.contains('\u0000')) {
      throw _unsafe('NUL in archive entry name: $rawName');
    }
    if (name.contains('\\')) {
      throw _unsafe('backslash in archive entry name: $rawName');
    }
    if (name.startsWith('/')) {
      throw _unsafe('absolute archive entry name: $rawName');
    }
    if (_driveLetter.hasMatch(name)) {
      throw _unsafe('drive letter in archive entry name: $rawName');
    }
    while (name.endsWith('/')) {
      name = name.substring(0, name.length - 1);
    }
    if (name.isEmpty) {
      throw _unsafe('archive entry is the root: $rawName');
    }
    final segments = name.split('/');
    for (final segment in segments) {
      if (segment.isEmpty || segment == '.' || segment == '..') {
        throw _unsafe('unclean archive entry path: $rawName');
      }
    }
    return segments;
  }

  _StrippedPath _stripPrefix(
    List<String> segments,
    String rawName,
    bool isDirectory,
  ) {
    final prefix = _prefix;
    if (prefix == null) {
      if (segments.length == 1) {
        if (!isDirectory) {
          throw _unsafe(
            'archive entries have no single top-level directory: $rawName',
          );
        }
        _prefix = segments.first;
        return const _StrippedPath.root();
      }
      _prefix = segments.first;
      return _StrippedPath(relative: segments.skip(1).join('/'));
    }

    if (segments.first != prefix) {
      throw _unsafe(
        'entry outside the top-level "$prefix/" directory: $rawName',
      );
    }
    if (segments.length == 1) {
      if (!isDirectory) {
        throw _unsafe('entry is not a directory: $rawName');
      }
      return const _StrippedPath.root();
    }
    return _StrippedPath(relative: segments.skip(1).join('/'));
  }

  void _validateLink(String relative, String target) {
    if (target.isEmpty) {
      throw _unsafe('empty symlink target: $relative');
    }
    if (target.contains('\u0000') || target.contains('\\')) {
      throw _unsafe('unsafe symlink target "$target" for $relative');
    }
    if (target.startsWith('/') || _driveLetter.hasMatch(target)) {
      throw _unsafe('absolute symlink target "$target" for $relative');
    }
    final resolved = p.posix.normalize(
      p.posix.join(p.posix.dirname(relative), target),
    );
    if (p.posix.isAbsolute(resolved) ||
        resolved == '..' ||
        resolved.startsWith('../')) {
      throw _unsafe('symlink "$relative" escapes the destination: $target');
    }
  }

  void _createLink(_PendingLink link) {
    final absolute = p.joinAll(<String>[
      destination.path,
      ...link.relative.split('/'),
    ]);
    _ensureParent(absolute);
    final type = FileSystemEntity.typeSync(absolute, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      throw _unsafe('symlink collides with a directory: ${link.relative}');
    }
    if (type == FileSystemEntityType.file) {
      File(absolute).deleteSync();
    } else if (type == FileSystemEntityType.link) {
      Link(absolute).deleteSync();
    }
    try {
      Link(absolute).createSync(link.target, recursive: true);
    } on Object catch (error) {
      throw RuntimeException(
        RuntimeFailureCode.extraction,
        'could not create symlink ${link.relative}: $error',
        cause: error,
      );
    }
  }

  void _writeFile(ArchiveFile entry, String relative, String absolute) {
    _ensureParent(absolute);
    final type = FileSystemEntity.typeSync(absolute, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      throw _unsafe('file entry collides with a directory: $relative');
    }
    if (type == FileSystemEntityType.link) {
      Link(absolute).deleteSync();
    }

    OutputFileStream? output;
    try {
      output = OutputFileStream(absolute);
      entry.writeContent(output);
      output.closeSync();
      if (output.length != entry.size) {
        throw RuntimeException(
          RuntimeFailureCode.extraction,
          'entry $relative wrote ${output.length} of ${entry.size} bytes',
        );
      }
    } on RuntimeException {
      output?.closeSync();
      _deleteQuietly(absolute);
      rethrow;
    } on Object catch (error) {
      output?.closeSync();
      _deleteQuietly(absolute);
      throw RuntimeException(
        RuntimeFailureCode.extraction,
        'could not extract $relative: $error',
        cause: error,
      );
    }

    _queuePermissions(absolute, relative);
  }

  void _ensureParent(String absolute) {
    final parent = Directory(p.dirname(absolute));
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
  }

  void _queuePermissions(String absolute, String relative) {
    if (Platform.isWindows) {
      return;
    }
    final desired = _looksExecutable(relative, absolute) ? 0x1ed : 0x1a4;
    if (_currentMode(absolute) == desired) {
      return;
    }
    (_modes[desired] ??= <String>[]).add(absolute);
  }

  void _applyPermissions() {
    for (final entry in _modes.entries) {
      final mode = entry.key.toRadixString(8).padLeft(3, '0');
      final paths = entry.value;
      for (var offset = 0; offset < paths.length; offset += 200) {
        final end = offset + 200 < paths.length ? offset + 200 : paths.length;
        final batch = paths.sublist(offset, end);
        final result = Process.runSync('chmod', <String>[mode, ...batch]);
        if (result.exitCode != 0) {
          throw RuntimeException(
            RuntimeFailureCode.extraction,
            'could not set permissions on ${batch.join(', ')}: '
            '${result.stderr}',
          );
        }
      }
    }
  }

  static int? _currentMode(String path) {
    try {
      return FileStat.statSync(path).mode & 0x1ff;
    } on Object {
      return null;
    }
  }

  static Uint8List _head(String path) {
    RandomAccessFile? file;
    try {
      file = File(path).openSync();
      return file.readSync(4);
    } on Object {
      return Uint8List(0);
    } finally {
      file?.closeSync();
    }
  }

  static bool _looksExecutable(String relative, String absolute) {
    final name = p.basename(relative).toLowerCase();
    if (name.endsWith('.exe') ||
        name.contains('.so') ||
        name.endsWith('.dylib') ||
        name.startsWith('llama-')) {
      return true;
    }
    return _hasBinaryMagic(_head(absolute));
  }

  static bool _hasBinaryMagic(Uint8List head) {
    if (head.length >= 4 &&
        head[0] == 0x7f &&
        head[1] == 0x45 &&
        head[2] == 0x4c &&
        head[3] == 0x46) {
      return true;
    }
    if (head.length < 4) {
      return false;
    }
    final magic = (head[0] << 24) | (head[1] << 16) | (head[2] << 8) | head[3];
    return switch (magic) {
      0xfeedface || 0xfeedfacf || 0xcefaedfe || 0xcffaedfe => true,
      0xcafebabe || 0xbebafeca => true,
      _ => false,
    };
  }

  static void _deleteQuietly(String path) {
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.file) {
        File(path).deleteSync();
      } else if (type == FileSystemEntityType.directory) {
        Directory(path).deleteSync(recursive: true);
      } else if (type == FileSystemEntityType.link) {
        Link(path).deleteSync();
      }
    } on Object {
      // The staging tree is cleaned up by the caller.
    }
  }

  RuntimeException _unsafe(String message) =>
      RuntimeException(RuntimeFailureCode.unsafeArchive, message);
}

final class _StrippedPath {
  const _StrippedPath({required this.relative}) : isRoot = false;

  const _StrippedPath.root() : relative = '', isRoot = true;

  final String relative;
  final bool isRoot;
}

final class _PendingLink {
  const _PendingLink({required this.relative, required this.target});

  final String relative;
  final String target;
}

final RegExp _driveLetter = RegExp(r'^[A-Za-z]:');
