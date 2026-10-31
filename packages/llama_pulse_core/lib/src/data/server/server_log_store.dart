import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import '../../domain/entities/server_log_entry.dart';
import '../../domain/entities/server_log_stream.dart';

/// Append-only store for supervisor and `llama-server` output.
///
/// The store keeps the newest entries in memory for the dashboard and writes
/// the same entries to [filePath] as
/// `timestampEpochMs\tsequence\tstream\tline\n`. One backup, `<filePath>.1`,
/// holds the lines rotated out at [rotationBytes]. Files written before the
/// sequence column was added (three fields) are still read, with sequence 0.
final class ServerLogStore {
  /// Creates a store that keeps [capacity] entries in memory.
  ///
  /// Lines longer than [maxLineLength] are truncated before they are stored.
  ServerLogStore({
    required this._filePath,
    int capacity = 1000,
    int maxLineLength = 8192,
  }) : _capacity = capacity < 1 ? 1 : capacity,
       _maxLineLength = maxLineLength < 1 ? 1 : maxLineLength;

  /// Size at which the active log file is rotated to `<filePath>.1`.
  static const int rotationBytes = 1024 * 1024;

  static final RegExp _ansi = RegExp(r'\x1B\[[0-9;]*[A-Za-z]');

  final String _filePath;
  final int _capacity;
  final int _maxLineLength;
  final ListQueue<ServerLogEntry> _ring = ListQueue<ServerLogEntry>();
  final StreamController<ServerLogEntry> _controller =
      StreamController<ServerLogEntry>.broadcast();
  final List<String> _pending = <String>[];

  Future<void> _tail = Future<void>.value();
  Future<void>? _historyLoad;
  bool _drainScheduled = false;
  bool _disposed = false;
  int _sequence = 0;

  /// Entries appended or loaded since the store was created, oldest first.
  Stream<ServerLogEntry> get entries => _controller.stream;

  /// The newest in-memory entries, oldest first, capped at `capacity`.
  List<ServerLogEntry> get recent => List<ServerLogEntry>.unmodifiable(_ring);

  String get _backupPath => '$_filePath.1';

  /// Adds [line] to the ring, the stream and the write queue.
  ///
  /// ANSI escapes are removed and the text is capped at `maxLineLength`; the
  /// call never waits for the file write. Use [flush] when the write must be
  /// visible on disk.
  void append(ServerLogStream stream, String line) {
    if (_disposed) {
      return;
    }
    final entry = ServerLogEntry(
      (b) => b
        ..sequence = ++_sequence
        ..timestampEpochMs = DateTime.now().millisecondsSinceEpoch
        ..stream = stream
        ..line = _sanitize(line),
    );
    _remember(entry);
    _pending.add(_record(entry));
    _scheduleDrain();
  }

  /// Waits until everything appended before the call is written to disk.
  Future<void> flush() async {
    _scheduleDrain();
    await _tail;
  }

  /// Reads the newest [lines] entries from disk, oldest first.
  ///
  /// When the active file holds fewer than [lines] entries and [includeBackup]
  /// is true, the rotated backup is read first. Each entry keeps the sequence
  /// stored on disk; legacy three-field lines carry sequence 0.
  Future<List<ServerLogEntry>> tail(
    int lines, {
    bool includeBackup = true,
  }) async {
    if (lines <= 0) {
      return const <ServerLogEntry>[];
    }
    final current = await _parse(File(_filePath));
    var combined = current;
    if (includeBackup && current.length < lines) {
      final backup = await _parse(File(_backupPath));
      combined = <ServerLogEntry>[...backup, ...current];
    }
    return combined.length > lines
        ? combined.sublist(combined.length - lines)
        : combined;
  }

  /// Removes the in-memory entries and deletes the log files.
  Future<void> clear() async {
    await flush();
    _ring.clear();
    for (final path in <String>[_filePath, _backupPath]) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // The log is best effort: a locked file must not break the caller.
      }
    }
  }

  /// Loads the newest [max] entries of the existing file into the ring.
  ///
  /// Unparsable lines are skipped, so a partially written line from an earlier
  /// crash does not poison the history.
  Future<void> loadExisting({int max = 1000}) {
    if (max <= 0) {
      return Future<void>.value();
    }
    final loaded = _historyLoad;
    if (loaded != null) {
      return loaded;
    }
    final future = _loadExisting(max);
    _historyLoad = future;
    return future;
  }

  Future<void> _loadExisting(int max) async {
    final current = await _parse(File(_filePath));
    final backup = await _parse(File(_backupPath));
    // Continue numbering after the newest stored line, across both files, so a
    // supervisor restart keeps `tail()` monotonic. Every entry keeps its own
    // stored sequence.
    for (final entry in <ServerLogEntry>[...backup, ...current]) {
      if (entry.sequence > _sequence) {
        _sequence = entry.sequence;
      }
    }
    final combined = current.length < max
        ? <ServerLogEntry>[...backup, ...current]
        : current;
    final selected = combined.length > max
        ? combined.sublist(combined.length - max)
        : combined;
    for (final entry in selected) {
      _remember(entry);
    }
  }

  /// Writes pending lines and closes the entries stream. Safe to call twice.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await flush();
    await _controller.close();
  }

  void _remember(ServerLogEntry entry) {
    _ring.addLast(entry);
    while (_ring.length > _capacity) {
      _ring.removeFirst();
    }
    if (!_controller.isClosed) {
      _controller.add(entry);
    }
  }

  String _sanitize(String line) {
    var text = line.replaceAll(_ansi, '');
    if (text.endsWith('\r')) {
      text = text.substring(0, text.length - 1);
    }
    // The file format is line based, so embedded breaks become spaces.
    text = text.replaceAll('\r', ' ').replaceAll('\n', ' ');
    if (text.length > _maxLineLength) {
      text = text.substring(0, _maxLineLength);
    }
    return text;
  }

  String _record(ServerLogEntry entry) =>
      '${entry.timestampEpochMs}\t${entry.sequence}\t${entry.stream.name}\t'
      '${entry.line}\n';

  void _scheduleDrain() {
    if (_drainScheduled) {
      return;
    }
    _drainScheduled = true;
    _tail = _tail.then((_) => _drain());
  }

  Future<void> _drain() async {
    _drainScheduled = false;
    while (_pending.isNotEmpty) {
      final batch = List<String>.of(_pending);
      _pending.clear();
      try {
        await _write(batch);
      } catch (_) {
        // Losing a log line is preferable to failing the caller.
      }
    }
  }

  Future<void> _write(List<String> records) async {
    final file = File(_filePath);
    var size = 0;
    try {
      if (await file.exists()) {
        size = await file.length();
      }
    } catch (_) {
      size = 0;
    }

    final buffer = StringBuffer();
    for (final record in records) {
      final bytes = utf8.encode(record).length;
      if (size > 0 && size + bytes > rotationBytes) {
        await _append(buffer.toString());
        buffer.clear();
        await _rotate();
        size = 0;
      }
      buffer.write(record);
      size += bytes;
    }
    await _append(buffer.toString());
  }

  Future<void> _append(String text) async {
    if (text.isEmpty) {
      return;
    }
    final file = File(_filePath);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(text, mode: FileMode.append);
  }

  Future<void> _rotate() async {
    try {
      final backup = File(_backupPath);
      if (await backup.exists()) {
        await backup.delete();
      }
      final file = File(_filePath);
      if (await file.exists()) {
        await file.rename(_backupPath);
      }
    } catch (_) {
      // Rotation is best effort; the next record tries again.
    }
  }

  Future<List<ServerLogEntry>> _parse(File file) async {
    final entries = <ServerLogEntry>[];
    try {
      if (!await file.exists()) {
        return entries;
      }
      final lines = await file.readAsLines();
      for (final line in lines) {
        final entry = _parseLine(line);
        if (entry != null) {
          entries.add(entry);
        }
      }
    } catch (_) {
      return entries;
    }
    return entries;
  }

  ServerLogEntry? _parseLine(String line) {
    final firstTab = line.indexOf('\t');
    if (firstTab <= 0) {
      return null;
    }
    final secondTab = line.indexOf('\t', firstTab + 1);
    if (secondTab < 0) {
      return null;
    }
    final timestamp = int.tryParse(line.substring(0, firstTab));
    if (timestamp == null) {
      return null;
    }

    final second = line.substring(firstTab + 1, secondTab);
    final storedSequence = int.tryParse(second);
    final ServerLogStream stream;
    final String text;
    try {
      if (storedSequence == null) {
        // Legacy `timestamp\tstream\tline`; the sequence was never stored.
        stream = ServerLogStream.valueOf(second);
        text = line.substring(secondTab + 1);
      } else {
        final thirdTab = line.indexOf('\t', secondTab + 1);
        if (thirdTab < 0) {
          return null;
        }
        stream = ServerLogStream.valueOf(
          line.substring(secondTab + 1, thirdTab),
        );
        text = line.substring(thirdTab + 1);
      }
    } on ArgumentError {
      return null;
    }
    return ServerLogEntry(
      (b) => b
        ..sequence = storedSequence ?? 0
        ..timestampEpochMs = timestamp
        ..stream = stream
        ..line = text,
    );
  }
}
