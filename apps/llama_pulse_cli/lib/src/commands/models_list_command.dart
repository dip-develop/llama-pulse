import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';

/// Lists `.gguf` files under one or more directories.
final class ModelsListCommand extends LlamaPulseCommand {
  /// Creates the command.
  ModelsListCommand(super.services) {
    argParser
      ..addMultiOption(
        'dir',
        help: 'Directory to scan; repeat for several directories.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print the results as a single-line JSON object.',
      );
  }

  @override
  String get name => 'list';

  @override
  String get description =>
      'List .gguf model files. Default directory: '
      '${services.paths.modelsDirectory}';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final args = parsedArgs;
    final requested = args.multiOption('dir');
    final directories = requested.isEmpty
        ? [services.paths.modelsDirectory]
        : requested;
    final result = await services.scanner.scan(directories: directories);

    for (final warning in result.warnings) {
      services.err.writeln(warning);
    }

    if (args.flag('json')) {
      writeJsonLine(services.out, {
        'count': result.files.length,
        'files': [
          for (final file in result.files)
            {
              'path': file.path,
              'fileName': file.fileName,
              'sizeBytes': file.sizeBytes,
              'modifiedAtEpochMs': file.modifiedAtEpochMs,
            },
        ],
      });
    } else if (result.files.isEmpty) {
      services.out.writeln('No .gguf files found in ${directories.join(', ')}');
    } else {
      for (final file in result.files) {
        services.out.writeln(
          '${file.fileName}  ${formatSizeMiB(file.sizeBytes)}  ${file.path}',
        );
      }
    }
    return ExitCodes.ok;
  }
}
