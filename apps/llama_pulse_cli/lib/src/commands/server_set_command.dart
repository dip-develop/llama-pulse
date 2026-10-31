import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../server/server_options.dart';
import '../server/server_output.dart';

/// Applies flags to the stored server configuration and saves them.
final class ServerSetCommand extends LlamaPulseCommand {
  /// Creates the command.
  ServerSetCommand(super.services) {
    addServerOptionFlags(argParser, includeReset: true);
  }

  @override
  String get name => 'set';

  @override
  String get description =>
      'Validate and store server configuration. Config file: '
      '${services.paths.serverYamlFile}';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final parsed = parseServerOptions(parsedArgs, includeReset: true);
    if (parsed.errors.isNotEmpty) {
      for (final message in parsed.errors) {
        services.err.writeln('error: $message');
      }
      return ExitCodes.usage;
    }
    if (parsed.reset && parsed.overrides.hasAny) {
      services.err.writeln(
        'error: --reset cannot be combined with other server options',
      );
      return ExitCodes.usage;
    }

    final repository = services.serverConfigRepository;
    var config = parsed.reset
        ? ServerConfig.defaults()
        : await repository.load();
    config = parsed.overrides.applyTo(config);

    final violations = const ServerConfigValidator().validate(config);
    if (violations.isNotEmpty) {
      for (final violation in violations) {
        services.err.writeln('error: $violation');
      }
      return ExitCodes.usage;
    }

    try {
      await repository.save(config);
    } on ServerException catch (error) {
      services.err.writeln(
        'error: ${error.failure.code.name}: ${error.failure.message}',
      );
      return ExitCodes.usage;
    }

    writeServerDocument(
      services.out,
      repository.toDocument(config),
      json: parsed.json,
    );
    return ExitCodes.ok;
  }
}
