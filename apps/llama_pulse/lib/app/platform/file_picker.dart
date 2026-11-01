import 'package:file_selector/file_selector.dart';

/// Asks the user for any file.
///
/// Extracted behind an interface so widget code never talks to the platform
/// plugin and tests can answer the dialog without a real file system dialog.
/// Unlike the model and binary pickers this one filters nothing: catalog
/// parameters accept model files, adapters, grammars, certificates and logs.
abstract interface class FilePicker {
  /// Returns the selected path, or `null` when the user cancelled.
  ///
  /// [dialogTitle] is a hint the platform dialog may show; the file selector
  /// plugin has no title API, so the default implementation ignores it.
  Future<String?> pickFile({String? dialogTitle});
}

/// [FilePicker] backed by the platform file chooser.
final class SystemFilePicker implements FilePicker {
  /// Creates a picker that opens the native file dialog on each call.
  const SystemFilePicker();

  @override
  Future<String?> pickFile({String? dialogTitle}) async {
    try {
      // No type group: every catalog path parameter takes a different file
      // kind, and an empty list means "all files" on every platform.
      final XFile? file = await openFile();
      return file?.path;
    } on Object {
      // A missing or broken platform implementation is the same as "no file"
      // for the caller; the user can still type the path by hand.
      return null;
    }
  }
}
