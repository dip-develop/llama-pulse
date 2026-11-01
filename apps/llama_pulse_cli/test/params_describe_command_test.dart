import 'dart:convert';
import 'dart:io';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDirectory;
  late StringBuffer out;
  late StringBuffer err;
  late LlamaPulseCommandRunner runner;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'llamapulse_describe_',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    out = StringBuffer();
    err = StringBuffer();
    runner = LlamaPulseCommandRunner(
      CliServices(
        paths: AppPaths(configDirectory: tempDirectory.path),
        configStore: InMemoryConfigStore(),
        out: out,
        err: err,
      ),
    );
  });

  test('a known id prints flags, type, default, range and surface', () async {
    expect(await runner.run(['params', 'describe', 'top-k']), ExitCodes.ok);

    final text = out.toString();
    expect(text, contains('id: top-k'));
    expect(text, contains('flags: --top-k'));
    expect(text, contains('summary: Top-k sampling cutoff.'));
    expect(text, contains('type: int'));
    expect(text, contains('default: 40'));
    expect(text, contains('range: 0..'));
    expect(text, contains('env: LLAMA_ARG_TOP_K'));
    expect(text, contains('surfaces: server, embedded'));
    expect(text, contains('exposure: configurable'));
    expect(err.toString(), isEmpty);
  });

  test('a managed id prints its owner, reason and typed flag', () async {
    expect(await runner.run(['params', 'describe', 'threads']), ExitCodes.ok);

    final text = out.toString();
    expect(text, contains('id: threads'));
    expect(text, contains('flags: -t --threads'));
    expect(text, contains('surfaces: server, embedded'));
    expect(text, contains('exposure: managed'));
    expect(text, contains('owner: threads'));
    expect(text, contains('managedBy: ServerConfig'));
    expect(
      text,
      contains('reason: LlamaPulse always passes the configured thread count.'),
    );
  });

  test('json carries the documented fields and the catalog values', () async {
    expect(
      await runner.run(['params', 'describe', 'min-p', '--json']),
      ExitCodes.ok,
    );

    final object = jsonDecode(out.toString().trim()) as Map<String, Object?>;
    expect(object['schemaVersion'], 1);
    expect(object['id'], 'min-p');
    expect(object['type'], 'double');
    expect(object['defaultValue'], 0.05);
    expect(object['min'], 0);
    expect(object['max'], 1);
    expect(object['allowed'], isEmpty);
    expect(object['surfaces'], ['server', 'embedded']);
    expect(object['exposure'], 'configurable');
    expect(object['envVar'], 'LLAMA_ARG_MIN_P');
    expect(object['group'], 'sampling');
    expect(object['reason'], isNull);
  });

  test('json for an unsupported id includes the reason', () async {
    expect(
      await runner.run(['params', 'describe', 'server-base', '--json']),
      ExitCodes.ok,
    );

    final object = jsonDecode(out.toString().trim()) as Map<String, Object?>;
    expect(object['id'], 'server-base');
    expect(object['exposure'], 'unsupported');
    expect(object['surfaces'], isEmpty);
    expect(
      object['reason'],
      'CLI client mode: connects to another server instead of hosting one.',
    );
  });

  test('a removed id prints its replacement', () async {
    expect(await runner.run(['params', 'describe', 'draft']), ExitCodes.ok);

    final text = out.toString();
    expect(text, contains('exposure: removed'));
    expect(
      text,
      contains('replacement: --spec-draft-n-max or --spec-ngram-mod-n-max'),
    );
  });

  test('an unknown id exits 2 with the catalog hint', () async {
    expect(await runner.run(['params', 'describe', 'nope']), ExitCodes.usage);

    expect(
      err.toString(),
      "error: unknown parameter 'nope' (run `llamapulse params catalog`)\n",
    );
    expect(out.toString(), isEmpty);
  });

  test('a missing or extra id exits 2', () async {
    expect(await runner.run(['params', 'describe']), ExitCodes.usage);
    expect(err.toString(), contains('expected exactly one parameter id'));

    err.clear();
    expect(
      await runner.run(['params', 'describe', 'top-k', 'temp']),
      ExitCodes.usage,
    );
    expect(err.toString(), contains('expected exactly one parameter id'));
  });
}
