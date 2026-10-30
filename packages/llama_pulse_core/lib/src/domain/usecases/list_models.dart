import '../gateways/model_scanner.dart';

/// Lists model files, returning warnings for skipped directories instead of
/// throwing.
final class ListModels {
  /// Creates the use case over [scanner].
  const ListModels(this._scanner);

  final ModelScanner _scanner;

  /// Scans [directories], or nothing when they are omitted.
  Future<ModelScanResult> call({Iterable<String>? directories}) =>
      _scanner.scan(directories: directories ?? const []);
}
