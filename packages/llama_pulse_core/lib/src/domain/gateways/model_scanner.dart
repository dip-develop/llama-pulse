import '../entities/model_file_info.dart';

/// Discovers model files on disk.
abstract interface class ModelScanner {
  /// Scans [directories], collecting warnings instead of throwing.
  Future<ModelScanResult> scan({
    required Iterable<String> directories,
    bool recursive = false,
  });

  /// Returns metadata for [path], or `null` when it is not a readable `.gguf`.
  Future<ModelFileInfo?> inspect(String path);
}

/// Model files found by a scan, together with human-readable warnings.
///
/// Transient: produced on demand and never persisted, so it is a plain class
/// rather than a built_value. Producers must pass unmodifiable lists;
/// [ModelFileScanner] does.
final class ModelScanResult {
  /// Wraps [files] and [warnings]; callers must supply unmodifiable lists.
  const ModelScanResult({required this.files, required this.warnings});

  /// Matching model files, sorted by file name and then path.
  final List<ModelFileInfo> files;

  /// One message per directory that was skipped.
  final List<String> warnings;
}
