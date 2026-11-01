import 'package:llama_pulse/app/platform/file_picker.dart';

/// [FilePicker] that returns a canned path and counts its calls.
final class FakeFilePicker implements FilePicker {
  FakeFilePicker({this.path = '/models/fake.gguf'});

  /// Path returned on the next call; `null` simulates a cancelled dialog.
  String? path;

  /// Number of times [pickFile] was called.
  int calls = 0;

  /// Dialog titles passed to [pickFile], in call order.
  final List<String?> dialogTitles = [];

  @override
  Future<String?> pickFile({String? dialogTitle}) async {
    calls++;
    dialogTitles.add(dialogTitle);
    return path;
  }
}
