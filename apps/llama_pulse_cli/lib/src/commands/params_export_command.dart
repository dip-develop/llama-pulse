import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../params/params_options.dart';
import '../params/params_output.dart';

/// Prints the `llama-cli` argument vector for the embedded configuration.
///
/// The configuration is resolved from the stored `params.yaml` and the
/// `--param` overrides only; nothing is written.
final class ParamsExportCommand extends LlamaPulseCommand {
  /// Creates the command.
  ParamsExportCommand(super.services) {
    addParamOption(argParser);
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print the argument vector as a single-line JSON object.',
    );
  }

  @override
  String get name => 'export';

  @override
  String get description =>
      'Print the llama-cli argument vector for the stored embedded '
      'parameters, with optional --param overrides. Does not modify '
      '${services.paths.paramsYamlFile}.';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final paramArguments = parseParamArguments(parsedArgs);
    if (paramArguments.errors.isNotEmpty) {
      for (final message in paramArguments.errors) {
        services.err.writeln('error: $message');
      }
      return ExitCodes.usage;
    }

    final stored = await services.paramsRepository.load();
    final resolved = resolveEmbeddedParams(
      params: stored,
      paramOverrides: paramArguments.overrides,
    );
    if (resolved.errors.isNotEmpty) {
      for (final message in resolved.errors) {
        services.err.writeln('error: $message');
      }
      return ExitCodes.usage;
    }

    final violations = const ModelParamsValidator().validate(resolved.params);
    if (violations.isNotEmpty) {
      for (final violation in violations) {
        services.err.writeln('error: $violation');
      }
      return ExitCodes.usage;
    }

    final argv = const ModelArgumentBuilder().build(resolved.params);
    if (parsedArgs.flag('json')) {
      writeJsonLine(services.out, {
        'schemaVersion': paramsOutputSchemaVersion,
        'type': 'paramsExport',
        'argv': argv,
      });
    } else {
      services.out.writeln(argv.join(' '));
    }
    return ExitCodes.ok;
  }
}
