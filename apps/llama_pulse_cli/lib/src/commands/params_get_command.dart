import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../params/params_output.dart';

/// Prints the stored model parameters.
final class ParamsGetCommand extends LlamaPulseCommand {
  /// Creates the command.
  ParamsGetCommand(super.services) {
    argParser
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print the parameters as a single-line JSON object.',
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
      'Print the stored model parameters. Config file: '
      '${services.paths.paramsYamlFile}';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final repository = services.paramsRepository;
    final params = await repository.load();

    if (parsedArgs.flag('json')) {
      writeJsonLine(
        services.out,
        encodeParamsDocument(
          document: repository.toDocument(params),
          params: params,
        ),
      );
      return ExitCodes.ok;
    }

    if (parsedArgs.flag('show-modified')) {
      for (final id in modifiedModelParameterIds(params)) {
        final value = _effectiveValue(params, id);
        services.out.writeln('$id: ${_singleLine(value)}');
      }
      return ExitCodes.ok;
    }

    writeParamsDocument(
      services.out,
      repository.toDocument(params),
      json: false,
    );
    return ExitCodes.ok;
  }

  /// Keeps list values, which are newline-separated, on one output line.
  static String _singleLine(String value) => value.replaceAll('\n', r'\n');

  /// Returns the effective value of [id] for [params].
  static String _effectiveValue(ModelParams params, String id) =>
      ParameterValues.valueForModel(params, id) ?? '';
}
