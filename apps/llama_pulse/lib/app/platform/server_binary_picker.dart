import 'package:file_selector/file_selector.dart';

/// Asks the user for the `llama-server` executable.
///
/// Extracted behind an interface so widgets never touch the platform plugin
/// and tests answer without a dialog.
abstract interface class ServerBinaryPicker {
  /// Returns the selected path, or `null` when the user cancelled.
  Future<String?> pickExecutable();
}

/// [ServerBinaryPicker] backed by the platform file chooser.
final class FileSelectorServerBinaryPicker implements ServerBinaryPicker {
  /// Creates a picker that opens the native file dialog on each call.
  const FileSelectorServerBinaryPicker();

  @override
  Future<String?> pickExecutable() async {
    try {
      // Executables carry no reliable extension on Linux and macOS, and the
      // Windows filter would hide `llama-server.exe` variants, so no type
      // filter is applied.
      final XFile? file = await openFile();
      return file?.path;
    } on Object {
      // A missing or broken platform implementation is the same as "no file";
      // the user can still type the path by hand.
      return null;
    }
  }
}
