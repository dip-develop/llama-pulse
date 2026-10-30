import 'dart:io';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';

Future<void> main(List<String> arguments) async {
  final CliServices services;
  try {
    services = CliServices.production();
  } catch (error) {
    stderr.writeln('error: $error');
    exitCode = ExitCodes.failure;
    return;
  }
  try {
    exitCode = await LlamaPulseCommandRunner(services).run(arguments);
  } catch (error) {
    services.err.writeln('error: $error');
    exitCode = ExitCodes.failure;
  }
}
