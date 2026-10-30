import '../../llama_pulse_cli.dart';

/// Prints the CLI version.
final class VersionCommand extends LlamaPulseCommand {
  /// Creates the command.
  VersionCommand(super.services) {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print the version as a JSON object.',
    );
  }

  @override
  String get name => 'version';

  @override
  String get description => 'Print the CLI version.';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    if (parsedArgs.flag('json')) {
      writeJsonLine(services.out, {
        'name': 'llama_pulse_cli',
        'version': cliVersion,
      });
    } else {
      services.out.writeln('llamapulse $cliVersion');
    }
    return ExitCodes.ok;
  }
}
