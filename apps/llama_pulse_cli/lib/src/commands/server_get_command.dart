import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../server/server_output.dart';

/// Prints the `server.yaml` document.
final class ServerGetCommand extends LlamaPulseCommand {
  /// Creates the command.
  ServerGetCommand(super.services) {
    argParser
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print the configuration as a single-line JSON object.',
      )
      ..addFlag(
        'show-modified',
        negatable: false,
        help: 'Only print the parameters that differ from the defaults.',
      );
  }

  @override
  String get name => 'get';

  @override
  String get description =>
      'Print the stored server configuration. Config file: '
      '${services.paths.serverYamlFile}';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final repository = services.serverConfigRepository;
    final stored = await services.configStore.read(ConfigNames.server);
    final valid =
        stored != null && stored['schemaVersion'] == ServerConfig.schemaVersion;
    final config = valid ? await repository.load() : ServerConfig.defaults();
    final document = valid ? stored : repository.toDocument(config);

    if (parsedArgs.flag('json')) {
      writeJsonLine(
        services.out,
        encodeServerDocument(document: document, config: config),
      );
      return ExitCodes.ok;
    }

    if (parsedArgs.flag('show-modified')) {
      for (final id in modifiedServerParameterIds(config)) {
        final value = ParameterValues.valueFor(config, id) ?? '';
        services.out.writeln('$id: ${_singleLine(value)}');
      }
      return ExitCodes.ok;
    }

    writeServerDocument(services.out, document, json: false);
    return ExitCodes.ok;
  }

  /// Keeps list values, which are newline-separated, on one output line.
  static String _singleLine(String value) => value.replaceAll('\n', r'\n');
}
