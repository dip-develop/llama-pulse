import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../server/server_output.dart';

/// Prints the `server.yaml` document.
final class ServerGetCommand extends LlamaPulseCommand {
  /// Creates the command.
  ServerGetCommand(super.services) {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print the configuration as a single-line JSON object.',
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
    final stored = await services.configStore.read(ConfigNames.server);
    final document =
        stored != null && stored['schemaVersion'] == ServerConfig.schemaVersion
        ? stored
        : services.serverConfigRepository.toDocument(ServerConfig.defaults());
    writeServerDocument(services.out, document, json: parsedArgs.flag('json'));
    return ExitCodes.ok;
  }
}
