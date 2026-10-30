import '../entities/model_file_info.dart';
import '../gateways/model_scanner.dart';

/// Reports metadata for one file, or `null` when it is not a usable model.
final class InspectModel {
  /// Creates the use case over [scanner].
  const InspectModel(this._scanner);

  final ModelScanner _scanner;

  /// Returns metadata for [path], or `null` when it is missing or not a
  /// readable `.gguf`.
  Future<ModelFileInfo?> call(String path) => _scanner.inspect(path);
}
