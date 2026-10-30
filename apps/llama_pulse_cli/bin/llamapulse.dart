import 'dart:io';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';

Future<void> main(List<String> arguments) async {
  final services = CliServices.production();
  try {
    exitCode = await LlamaPulseCommandRunner(services).run(arguments);
  } catch (error) {
    services.err.writeln('error: $error');
    exitCode = ExitCodes.failure;
  }
}
