import 'dart:convert';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

import 'support/scripted_llama_engine.dart';

const _prompt = 'The quick brown fox jumps over the lazy dog.';

List<Map<String, Object?>> _lines(String text) => text
    .split('\n')
    .where((line) => line.isNotEmpty)
    .map((line) => jsonDecode(line) as Map<String, Object?>)
    .toList();

void main() {
  late StringBuffer out;
  late StringBuffer err;
  late ScriptedLlamaEngine engine;
  late InMemoryConfigStore store;

  setUp(() {
    out = StringBuffer();
    err = StringBuffer();
    engine = ScriptedLlamaEngine();
    store = InMemoryConfigStore();
  });

  LlamaPulseCommandRunner makeRunner() => LlamaPulseCommandRunner(
    CliServices(
      paths: const AppPaths(configDirectory: '/config/llamapulse'),
      configStore: store,
      out: out,
      err: err,
      engineFactory: () => engine,
    ),
  );

  test('--stub --json reports aggregates and every run', () async {
    final runner = makeRunner();

    final code = await runner.run([
      'bench',
      '--stub',
      '--json',
      '--runs',
      '2',
      '--model',
      '/tmp/demo.gguf',
    ]);

    expect(code, ExitCodes.ok);
    final result = _lines(out.toString()).single;
    expect(result['schemaVersion'], 1);
    expect(result['type'], 'bench');
    expect(result['runs'], 2);
    expect(result['modelPath'], '/tmp/demo.gguf');
    expect(result['promptChars'], _prompt.length);
    expect(result['promptTokenCount'], 5);
    expect(result['generatedTokenCount'], 4);
    expect(result['evalMs'], 40);
    expect(result['tokensPerSecond'], 100.0);

    final perRun = result['perRun'] as List<Object?>;
    expect(perRun.length, 2);
    final first = perRun.first as Map<String, Object?>;
    expect(first.keys.toList(), [
      'requestId',
      'generatedTokenCount',
      'evalMs',
      'tokensPerSecond',
    ]);
    expect(first['requestId'], 1);
    expect(first['generatedTokenCount'], 2);
    expect(first['evalMs'], 20);
    expect(first['tokensPerSecond'], 100.0);
    expect((perRun.last as Map<String, Object?>)['requestId'], 2);

    expect(engine.loadCalls, 1);
    expect(engine.generateCalls, 2);
    expect(engine.generateRequests.map((request) => request.requestId), [1, 2]);
    expect(engine.unloadCalls, 1);
    expect(engine.disposeCalls, 1);
  });

  test('the default run count is 3', () async {
    final runner = makeRunner();

    expect(
      await runner.run([
        'bench',
        '--stub',
        '--json',
        '--model',
        '/tmp/demo.gguf',
      ]),
      ExitCodes.ok,
    );

    final result = _lines(out.toString()).single;
    expect(result['runs'], 3);
    expect((result['perRun'] as List<Object?>).length, 3);
    expect(engine.generateCalls, 3);
  });

  test('--stub without a configured model uses the stub placeholder', () async {
    final runner = makeRunner();

    expect(
      await runner.run(['bench', '--stub', '--json', '--runs', '1']),
      ExitCodes.ok,
    );

    final result = _lines(out.toString()).single;
    expect(result['modelPath'], '<stub>');
    expect(engine.loadedParams?.modelPath, '<stub>');
    expect(engine.generateCalls, 1);
  });

  test('--runs 0 is a usage error before engine creation', () async {
    final runner = makeRunner();

    expect(
      await runner.run(['bench', '--runs', '0', '--model', '/tmp/demo.gguf']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('--runs must be an integer in 1..50'));
    expect(engine.loadCalls, 0);
  });

  test('--runs 51 is a usage error', () async {
    final runner = makeRunner();

    expect(
      await runner.run(['bench', '--runs', '51', '--model', '/tmp/demo.gguf']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('--runs must be an integer in 1..50'));
  });

  test('without --stub exits 1 and reports engineUnavailable', () async {
    final runner = makeRunner();

    final code = await runner.run(['bench', '--model', '/tmp/demo.gguf']);

    expect(code, ExitCodes.failure);
    expect(out.toString(), isEmpty);
    expect(err.toString(), contains('error: engineUnavailable:'));
    expect(engine.loadCalls, 0);
  });

  test(
    'human output puts per-run lines on stderr and the summary on stdout',
    () async {
      final runner = makeRunner();

      expect(
        await runner.run([
          'bench',
          '--stub',
          '--runs',
          '2',
          '--model',
          '/tmp/demo.gguf',
        ]),
        ExitCodes.ok,
      );

      expect(
        out.toString(),
        'runs: 2  generatedTokens: 4  evalMs: 40  tokensPerSecond: 100.00\n',
      );
      final lines = err.toString().trim().split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, 'run 1: 2 tokens in 20 ms (100.00 tok/s)');
      expect(lines.last, 'run 2: 2 tokens in 20 ms (100.00 tok/s)');
      expect(engine.unloadCalls, 1);
      expect(engine.disposeCalls, 1);
    },
  );
}
