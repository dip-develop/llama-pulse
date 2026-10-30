import 'dart:convert';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  late StringBuffer out;
  late StringBuffer err;
  late LlamaPulseCommandRunner runner;

  setUp(() {
    out = StringBuffer();
    err = StringBuffer();
    runner = LlamaPulseCommandRunner(
      CliServices(
        paths: const AppPaths(configDirectory: '/config/llamapulse'),
        configStore: InMemoryConfigStore(),
        out: out,
        err: err,
      ),
    );
  });

  test('prints the version on stdout', () async {
    expect(await runner.run(['version']), ExitCodes.ok);

    expect(out.toString(), 'llamapulse $cliVersion\n');
    expect(err.toString(), isEmpty);
  });

  test('--json prints a single JSON object', () async {
    expect(await runner.run(['version', '--json']), ExitCodes.ok);

    expect(
      out.toString(),
      '{"name":"llama_pulse_cli","version":"$cliVersion"}\n',
    );
    expect(jsonDecode(out.toString().trim()), {
      'name': 'llama_pulse_cli',
      'version': cliVersion,
    });
    expect(err.toString(), isEmpty);
  });

  test('unknown command exits with a usage error on stderr', () async {
    expect(await runner.run(['does-not-exist']), ExitCodes.usage);

    expect(out.toString(), isEmpty);
    expect(err.toString(), contains('error:'));
    expect(err.toString(), contains('Usage: llamapulse'));
    expect(err.toString(), contains('Available commands:'));
  });
}
