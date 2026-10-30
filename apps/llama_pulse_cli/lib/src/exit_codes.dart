/// Process exit codes used by the CLI.
abstract final class ExitCodes {
  /// The command completed successfully.
  static const int ok = 0;

  /// An unexpected failure escaped the command.
  static const int failure = 1;

  /// The arguments were invalid or the supplied values failed validation.
  static const int usage = 2;

  /// The requested model file does not exist or is not a `.gguf` file.
  static const int notFound = 3;
}
