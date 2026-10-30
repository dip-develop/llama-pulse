import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  const launcher = DartProcessLauncher();

  Future<ServerProcess> launch(String script) async {
    final process = await launcher.start('/bin/sh', ['-c', script]);
    addTearDown(() {
      process.kill(ServerKillMode.force);
    });
    return process;
  }

  test('streams stdout, stderr and the exit code', () async {
    final process = await launch(
      'printf "a\\nb\\n"; printf "err\\n" >&2; exit 3',
    );

    final output = await process.stdoutLines.toList();
    final errors = await process.stderrLines.toList();
    final exitCode = await process.exitCode;

    expect(output, ['a', 'b']);
    expect(errors, ['err']);
    expect(exitCode, 3);
  }, skip: Platform.isWindows ? 'POSIX shell' : null);

  test('strips ANSI escape sequences', () async {
    final process = await launch("printf '\u001B[31mred\u001B[0m\\n'");

    expect(await process.stdoutLines.toList(), ['red']);
    expect(await process.exitCode, 0);
  }, skip: Platform.isWindows ? 'POSIX shell' : null);

  test('kills a running process', () async {
    final process = await launch('sleep 30');

    expect(process.kill(ServerKillMode.force), isTrue);
    expect(await process.exitCode, isNot(0));
  }, skip: Platform.isWindows ? 'POSIX shell' : null);

  test('reports a graceful stop request on a live process', () async {
    final process = await launch('sleep 30');

    expect(process.kill(ServerKillMode.graceful), isTrue);
    await process.exitCode;
  }, skip: Platform.isWindows ? 'POSIX shell' : null);

  test('rejects an empty executable', () async {
    await expectLater(launcher.start('', const []), throwsArgumentError);
  });
}
