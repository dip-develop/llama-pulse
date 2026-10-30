import 'dart:async';

import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../server/server_output.dart';

/// Prints the newest supervisor and `llama-server` log lines.
final class LogsCommand extends LlamaPulseCommand {
  /// Creates the command.
  LogsCommand(super.services) {
    argParser
      ..addOption(
        'lines',
        defaultsTo: '100',
        help: 'Number of lines to print, 1..1000.',
      )
      ..addFlag(
        'follow',
        negatable: false,
        help: 'Keep printing new lines until interrupted.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print one JSON object per line.',
      );
  }

  @override
  String get name => 'logs';

  @override
  String get description =>
      'Print the server log. Log file: '
      '${services.paths.serverLogFile}';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final rawLines = parsedArgs.option('lines') ?? '100';
    final lines = int.tryParse(rawLines);
    if (lines == null || lines < 1 || lines > 1000) {
      services.err.writeln('error: --lines must be an integer in 1..1000');
      return ExitCodes.usage;
    }

    final json = parsedArgs.flag('json');
    final store = services.serverLogStore;
    final entries = await store.tail(lines);
    for (final entry in entries) {
      _write(entry, json: json);
    }

    if (!parsedArgs.flag('follow')) {
      return ExitCodes.ok;
    }

    final interrupted = Completer<void>();
    final interrupts = services.interrupts;
    final subscription = interrupts?.listen((_) {
      if (!interrupted.isCompleted) {
        interrupted.complete();
      }
    });
    try {
      var emitted = entries.length;
      while (!interrupted.isCompleted) {
        await Future.any(<Future<void>>[
          Future<void>.delayed(const Duration(milliseconds: 200)),
          interrupted.future,
        ]);
        if (interrupted.isCompleted) {
          break;
        }
        final all = await store.tail(1000);
        if (all.length < emitted) {
          emitted = 0;
        }
        for (final entry in all.skip(emitted)) {
          _write(entry, json: json);
        }
        emitted = all.length;
      }
    } finally {
      await subscription?.cancel();
    }
    return ExitCodes.interrupted;
  }

  void _write(ServerLogEntry entry, {required bool json}) {
    if (json) {
      writeJsonLine(services.out, encodeLogEntry(entry));
    } else {
      services.out.writeln('[${entry.stream.name}] ${entry.line}');
    }
  }
}
