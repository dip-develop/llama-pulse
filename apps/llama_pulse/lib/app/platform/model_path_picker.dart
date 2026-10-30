import 'package:file_selector/file_selector.dart';

/// Asks the user for a GGUF model file.
///
/// Extracted behind an interface so widgets never talk to the platform plugin
/// and tests can answer the dialog without a real file system dialog.
abstract interface class ModelPathPicker {
  /// Returns the selected path, or `null` when the user cancelled.
  Future<String?> pickGgufFile();
}

/// [ModelPathPicker] backed by the platform file chooser.
final class FileSelectorModelPathPicker implements ModelPathPicker {
  /// Creates a picker that opens the native file dialog on each call.
  const FileSelectorModelPathPicker();

  @override
  Future<String?> pickGgufFile() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'GGUF models', extensions: ['gguf']),
        ],
      );
      return file?.path;
    } on Object {
      // A missing or broken platform implementation is the same as "no file"
      // for the caller; the user can still type the path by hand.
      return null;
    }
  }
}
