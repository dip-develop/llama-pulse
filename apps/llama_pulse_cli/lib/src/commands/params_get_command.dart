import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';

/// Prints the stored model parameters.
final class ParamsGetCommand extends LlamaPulseCommand {
  /// Creates the command.
  ParamsGetCommand(super.services) {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print the parameters as a single-line JSON object.',
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
    writeParamsDocument(
      services.out,
      repository.toDocument(params),
      json: parsedArgs.flag('json'),
    );
    return ExitCodes.ok;
  }
}
