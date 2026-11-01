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

  /// A downloaded runtime failed verification or extraction.
  static const int integrity = 4;

  /// The runtime download failed at the network or HTTP layer.
  static const int network = 5;

  /// The user interrupted the running command (128 + SIGINT).
  static const int interrupted = 130;
}
