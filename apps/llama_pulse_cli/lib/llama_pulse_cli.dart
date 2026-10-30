/// Command-line interface for LlamaPulse parameters and local model files.
library;

export 'src/cli_services.dart';
export 'src/command_runner.dart';
export 'src/exit_codes.dart';
export 'src/output.dart';

/// Version reported by the `version` command and the compiled executable.
const String cliVersion = '0.1.0';
