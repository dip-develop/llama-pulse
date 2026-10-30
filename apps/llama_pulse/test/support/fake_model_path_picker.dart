import 'package:llama_pulse/app/platform/model_path_picker.dart';

/// [ModelPathPicker] that returns a canned path and counts its calls.
final class FakeModelPathPicker implements ModelPathPicker {
  FakeModelPathPicker({this.path = '/models/fake.gguf'});

  /// Path returned on the next call; `null` simulates a cancelled dialog.
  String? path;

  /// Number of times [pickGgufFile] was called.
  int calls = 0;

  @override
  Future<String?> pickGgufFile() async {
    calls++;
    return path;
  }
}
