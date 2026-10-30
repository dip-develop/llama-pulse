import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/model_file_info.dart';
import '../../domain/gateways/model_scanner.dart';

/// Finds `.gguf` files on disk without throwing.
final class ModelFileScanner implements ModelScanner {
  /// Creates a scanner.
  const ModelFileScanner();

  @override
  Future<ModelScanResult> scan({
    required Iterable<String> directories,
    bool recursive = false,
  }) async {
    final byPath = <String, ModelFileInfo>{};
    final warnings = <String>[];
    for (final directory in directories) {
      await _scanDirectory(
        Directory(directory),
        recursive: recursive,
        byPath: byPath,
        warnings: warnings,
      );
    }
    final files = byPath.values.toList()..sort(_compare);
    return ModelScanResult(
      files: List.unmodifiable(files),
      warnings: List.unmodifiable(warnings),
    );
  }

  @override
  Future<ModelFileInfo?> inspect(String path) async {
    if (!_isGguf(path)) {
      return null;
    }
    final file = File(path);
    try {
      if (!await file.exists()) {
        return null;
      }
      return await _readInfo(file);
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _scanDirectory(
    Directory directory, {
    required bool recursive,
    required Map<String, ModelFileInfo> byPath,
    required List<String> warnings,
  }) async {
    final List<FileSystemEntity> entries;
    try {
      if (!await directory.exists()) {
        warnings.add('${directory.path} is not a readable directory');
        return;
      }
      entries = await directory.list(followLinks: false).toList();
    } on FileSystemException {
      warnings.add('${directory.path} is not a readable directory');
      return;
    }
    for (final entry in entries) {
      if (entry is Directory) {
        if (recursive) {
          await _scanDirectory(
            entry,
            recursive: true,
            byPath: byPath,
            warnings: warnings,
          );
        }
      } else if (entry is File && _isGguf(entry.path)) {
        await _add(entry, byPath);
      }
    }
  }

  Future<void> _add(File file, Map<String, ModelFileInfo> byPath) async {
    try {
      final info = await _readInfo(file);
      byPath.putIfAbsent(info.path, () => info);
    } on FileSystemException {
      // The file vanished or became unreadable after it was listed.
    }
  }

  Future<ModelFileInfo> _readInfo(File file) async {
    final path = await file.resolveSymbolicLinks();
    final stat = await file.stat();
    return ModelFileInfo(
      (b) => b
        ..path = path
        ..fileName = p.basename(path)
        ..sizeBytes = stat.size
        ..modifiedAtEpochMs = stat.modified.millisecondsSinceEpoch,
    );
  }

  bool _isGguf(String path) => p.extension(path).toLowerCase() == '.gguf';

  int _compare(ModelFileInfo a, ModelFileInfo b) {
    final byName = a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
    return byName != 0 ? byName : a.path.compareTo(b.path);
  }
}
