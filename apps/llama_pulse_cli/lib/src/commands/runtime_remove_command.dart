import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../runtime/runtime_commands_support.dart';
import '../runtime/runtime_output.dart';

/// Deletes one installed runtime.
final class RuntimeRemoveCommand extends LlamaPulseCommand {
  /// Creates the command.
  RuntimeRemoveCommand(super.services) {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print the removal as a single-line JSON object.',
    );
  }

  @override
  String get name => 'remove';

  @override
  String get description =>
      'Delete an installed runtime and drop it from the index.';

  @override
  String get usage => '$name <tag> <backend>';

  @override
  Future<int> run() async {
    final (tag, backend, error) = _target();
    if (error != null) {
      return _fail(error, code: ExitCodes.usage);
    }
    final store = services.runtimes;
    final manifest = await store.manifest(tag!, backend!);
    if (manifest == null) {
      return _fail(
        'runtime $tag/${backend.id} is not installed',
        code: ExitCodes.notFound,
      );
    }
    await store.remove(tag, backend);
    if (parsedArgs.flag('json')) {
      writeJsonLine(services.out, {
        'schemaVersion': runtimeOutputSchemaVersion,
        'type': 'runtimeRemoved',
        'removed': {'tag': tag, 'backend': backend.id},
      });
    } else {
      services.out.writeln('removed $tag/${backend.id}');
    }
    return ExitCodes.ok;
  }

  (String?, RuntimeBackend?, String?) _target() {
    final rest = parsedArgs.rest;
    if (rest.length != 2) {
      return (null, null, 'expected <tag> <backend>');
    }
    final backend = parseRuntimeBackend(rest[1]);
    if (backend == null) {
      return (null, null, 'unknown backend "${rest[1]}"');
    }
    return (rest[0], backend, null);
  }

  int _fail(String message, {required int code}) {
    services.err.writeln('error: $message');
    if (parsedArgs.flag('json')) {
      writeJsonLine(
        services.out,
        encodeRuntimeFailed(
          command: 'remove',
          code: code == ExitCodes.notFound ? 'notFound' : 'usage',
          message: message,
        ),
      );
    }
    return code;
  }
}
