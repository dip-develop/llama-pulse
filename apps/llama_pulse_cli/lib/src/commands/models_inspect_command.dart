import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';

/// Prints metadata for a single model file.
final class ModelsInspectCommand extends LlamaPulseCommand {
  /// Creates the command.
  ModelsInspectCommand(super.services) {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print the metadata as a single-line JSON object.',
    );
  }

  @override
  String get name => 'inspect';

  @override
  String get description => 'Print metadata for one .gguf model file.';

  @override
  Future<int> run() async {
    final args = parsedArgs;
    if (args.rest.length != 1) {
      services.err.writeln('error: expected exactly one model path');
      return ExitCodes.usage;
    }
    final path = args.rest.single;
    final info = await services.scanner.inspect(path);
    if (info == null) {
      services.err.writeln('error: not found: $path');
      return ExitCodes.notFound;
    }

    final modified = DateTime.fromMillisecondsSinceEpoch(
      info.modifiedAtEpochMs,
      isUtc: true,
    ).toIso8601String();
    if (args.flag('json')) {
      writeJsonLine(services.out, {
        'path': info.path,
        'fileName': info.fileName,
        'sizeMiB': double.parse(formatSizeMiB(info.sizeBytes)),
        'modified': modified,
      });
    } else {
      services.out
        ..writeln('path: ${info.path}')
        ..writeln('fileName: ${info.fileName}')
        ..writeln('sizeMiB: ${formatSizeMiB(info.sizeBytes)}')
        ..writeln('modified: $modified');
    }
    return ExitCodes.ok;
  }
}
