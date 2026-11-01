import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
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
    final parseErrors = [...parsed.errors, ...parsed.paramErrors];
    if (parseErrors.isNotEmpty) {
      for (final message in parseErrors) {
        services.err.writeln('error: $message');
      }
      return ExitCodes.usage;
    }
    if (parsed.reset && (parsed.overrides.hasAny || parsed.hasParamOverrides)) {
      services.err.writeln(
        'error: --reset cannot be combined with other server options',
      );
      return ExitCodes.usage;
    }

    final repository = services.serverConfigRepository;
    final stored = parsed.reset
        ? ServerConfig.defaults()
        : await repository.load();
    final resolved = resolveServerConfig(
      config: stored,
      overrides: parsed.overrides,
      paramOverrides: parsed.paramOverrides,
      forStart: false,
    );
    if (resolved.errors.isNotEmpty) {
      for (final message in resolved.errors) {
        services.err.writeln('error: $message');
      }
      return ExitCodes.usage;
    }
    final config = resolved.config;

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

    final document = repository.toDocument(config);
    if (parsed.json) {
      writeJsonLine(
        services.out,
        encodeServerDocument(document: document, config: config),
      );
    } else {
      writeServerDocument(services.out, document, json: false);
    }
    return ExitCodes.ok;
  }
}
