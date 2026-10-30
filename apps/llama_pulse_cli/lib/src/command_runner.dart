import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'cli_services.dart';
import 'commands/bench_command.dart';
import 'commands/models_inspect_command.dart';
import 'commands/models_list_command.dart';
import 'commands/params_get_command.dart';
import 'commands/params_set_command.dart';
import 'commands/run_command.dart';
import 'commands/version_command.dart';
import 'exit_codes.dart';

/// Parses `llamapulse` arguments and dispatches to a command.
final class LlamaPulseCommandRunner extends CommandRunner<int> {
  /// Creates a runner over [services] and registers every command.
  LlamaPulseCommandRunner(this.services)
    : super(
        'llamapulse',
        'Manage LlamaPulse parameters, model files and local inference.',
      ) {
    addCommand(VersionCommand(services));
    addCommand(_ParamsCommand(services));
    addCommand(_ModelsCommand(services));
    addCommand(RunCommand(services));
    addCommand(BenchCommand(services));
  }

  /// Dependencies handed to every command.
  final CliServices services;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final result = await super.run(args);
      return result ?? ExitCodes.ok;
    } on UsageException catch (error) {
      services.err
        ..writeln('error: ${error.message}')
        ..writeln(usage);
      return ExitCodes.usage;
    } catch (error) {
      // The CLI is the process-level error boundary: a failure in a command
      // must become a non-zero exit code, never an uncaught exception.
      services.err.writeln('error: $error');
      return ExitCodes.failure;
    }
  }

  @override
  void printUsage() => services.out.writeln(usage);
}

/// Base class for leaf commands that report through [services].
abstract class LlamaPulseCommand extends Command<int> {
  /// Creates a command bound to [services].
  LlamaPulseCommand(this.services);

  /// Dependencies and output sinks.
  final CliServices services;

  /// Arguments for the current run; set before [run] is invoked.
  ArgResults get parsedArgs {
    final results = argResults;
    if (results == null) {
      throw StateError('Command arguments were not parsed');
    }
    return results;
  }
}

/// The `params` command group.
final class _ParamsCommand extends Command<int> {
  _ParamsCommand(CliServices services) {
    addSubcommand(ParamsGetCommand(services));
    addSubcommand(ParamsSetCommand(services));
  }

  @override
  String get name => 'params';

  @override
  String get description => 'Read and update the stored model parameters.';
}

/// The `models` command group.
final class _ModelsCommand extends Command<int> {
  _ModelsCommand(CliServices services) {
    addSubcommand(ModelsListCommand(services));
    addSubcommand(ModelsInspectCommand(services));
  }

  @override
  String get name => 'models';

  @override
  String get description => 'List and inspect local model files.';
}
