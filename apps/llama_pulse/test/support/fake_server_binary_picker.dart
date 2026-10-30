import 'package:llama_pulse/app/platform/server_binary_picker.dart';

/// [ServerBinaryPicker] that returns a canned path and counts its calls.
final class FakeServerBinaryPicker implements ServerBinaryPicker {
  FakeServerBinaryPicker({this.path = '/opt/llama-server'});

  /// Path returned on the next call; `null` simulates a cancelled dialog.
  String? path;

  /// Number of times [pickExecutable] was called.
  int calls = 0;

  @override
  Future<String?> pickExecutable() async {
    calls++;
    return path;
  }
}
