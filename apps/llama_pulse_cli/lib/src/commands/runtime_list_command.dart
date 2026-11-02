import '../command_runner.dart';
import '../output.dart';
import '../runtime/runtime_output.dart';

/// Lists the runtimes installed under `<config>/runtime/`.
final class RuntimeListCommand extends LlamaPulseCommand {
  /// Creates the command.
  RuntimeListCommand(super.services) {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print the installed runtimes as a single-line JSON object.',
    );
  }

  @override
  String get name => 'list';

  @override
  String get description => 'List the installed llama.cpp runtimes.';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final index = await services.runtimes.index();
    if (parsedArgs.flag('json')) {
      writeJsonLine(services.out, encodeRuntimeList(index));
      return 0;
    }
    final selected = index.selected;
    final out = services.out;
    if (selected == null) {
      out.writeln('selected: none');
    } else {
      out.writeln('selected: ${selected.id}');
    }
    if (index.installed.isEmpty) {
      out.writeln('no runtimes installed');
      return 0;
    }
    for (final install in index.resolutionOrder) {
      final marker = selected != null && install.id == selected.id ? '*' : ' ';
      out.writeln(
        '$marker ${install.id.padRight(14)} '
        '${install.platform.id.padRight(12)} '
        '${formatRuntimeSize(install.sizeBytes)}',
      );
    }
    return 0;
  }
}
