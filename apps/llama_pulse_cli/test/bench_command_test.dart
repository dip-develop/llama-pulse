import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  LlamaPulseCommandRunner makeRunner({Stream<ProcessSignal>? interrupts}) =>
      LlamaPulseCommandRunner(
        CliServices(
          paths: const AppPaths(configDirectory: '/config/llamapulse'),
          configStore: store,
          out: out,
          err: err,
          interrupts: interrupts,
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

  test('without --stub loads a real model through the native engine', () async {
    final directory = Directory.systemTemp.createTempSync('llamapulse_bench');
    addTearDown(() => directory.deleteSync(recursive: true));
    final model = File('${directory.path}/tiny.gguf')..writeAsStringSync('');
    final runner = makeRunner();

    expect(
      await runner.run([
        'bench',
        '--json',
        '--runs',
        '1',
        '--model',
        model.path,
      ]),
      ExitCodes.ok,
    );

    expect(engine.loadCalls, 1);
    expect(engine.loadedParams?.modelPath, model.path);
    expect(engine.generateCalls, 1);
  });

  test(
    'without --stub reports libraryNotFound and the searched paths',
    () async {
      final directory = Directory.systemTemp.createTempSync('llamapulse_bench');
      addTearDown(() => directory.deleteSync(recursive: true));
      final model = File('${directory.path}/tiny.gguf')..writeAsStringSync('');
      final runner = LlamaPulseCommandRunner(
        CliServices(
          paths: const AppPaths(configDirectory: '/config/llamapulse'),
          configStore: store,
          out: out,
          err: err,
          engineFactory: () => WorkerLlamaEngine(libraryPath: ''),
        ),
      );

      final code = await runner.run([
        'bench',
        '--runs',
        '1',
        '--model',
        model.path,
      ]);

      expect(code, ExitCodes.failure);
      expect(out.toString(), isEmpty);
      expect(err.toString(), contains('error: libraryNotFound:'));
      expect(err.toString(), contains(LlamaLibraryLocator().libraryFileName));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('without --stub a blank model path is a usage error', () async {
    final runner = makeRunner();

    expect(
      await runner.run(['bench', '--model', '   ', '--runs', '1']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('model path is required'));
    expect(engine.loadCalls, 0);
  });

  test('without --stub a missing model is notFound', () async {
    final runner = makeRunner();

    expect(
      await runner.run(['bench', '--model', '/tmp/missing.gguf']),
      ExitCodes.notFound,
    );

    expect(err.toString(), contains('not found: /tmp/missing.gguf'));
    expect(engine.loadCalls, 0);
  });

  test('a missing model with --json emits one failed object', () async {
    final runner = makeRunner();

    expect(
      await runner.run(['bench', '--json', '--model', '/tmp/missing.gguf']),
      ExitCodes.notFound,
    );

    final event = _lines(out.toString()).single;
    expect(event['type'], 'failed');
    expect(event['requestId'], 1);
    expect(event['schemaVersion'], 1);
    expect(event['text'], '');
    expect((event['failure'] as Map<String, Object?>)['code'], 'modelNotFound');
    expect(err.toString(), contains('error: not found: /tmp/missing.gguf'));
    expect(engine.loadCalls, 0);
  });

  test('--runs 3 works with a broadcast interrupt stream', () async {
    final signals = StreamController<ProcessSignal>.broadcast();
    addTearDown(signals.close);
    final runner = makeRunner(interrupts: signals.stream);

    expect(
      await runner.run([
        'bench',
        '--stub',
        '--json',
        '--runs',
        '3',
        '--model',
        '/tmp/demo.gguf',
      ]),
      ExitCodes.ok,
    );

    final result = _lines(out.toString()).single;
    expect((result['perRun'] as List<Object?>).length, 3);
    expect(engine.generateCalls, 3);
    expect(err.toString(), isNot(contains('already been listened')));
  });

  test(
    '--runs 3 subscribes to a single-subscription source only once',
    () async {
      final signals = StreamController<ProcessSignal>();
      addTearDown(signals.close);
      final runner = makeRunner(interrupts: signals.stream);

      expect(
        await runner.run([
          'bench',
          '--stub',
          '--json',
          '--runs',
          '3',
          '--model',
          '/tmp/demo.gguf',
        ]),
        ExitCodes.ok,
      );

      final result = _lines(out.toString()).single;
      expect((result['perRun'] as List<Object?>).length, 3);
      expect(engine.generateCalls, 3);
      expect(err.toString(), isNot(contains('already been listened')));
    },
  );

  test('a failed run keeps the partial text in --json output', () async {
    engine = ScriptedLlamaEngine(
      tokens: const ['Hello'],
      failAfterTokens: true,
      generateFailure: InferenceFailure(
        (b) => b
          ..code = InferenceFailureCode.nativeError
          ..message = 'decode failed',
      ),
    );
    final runner = makeRunner();

    expect(
      await runner.run([
        'bench',
        '--stub',
        '--json',
        '--runs',
        '1',
        '--model',
        '/tmp/demo.gguf',
      ]),
      ExitCodes.failure,
    );

    final event = _lines(out.toString()).single;
    expect(event['type'], 'failed');
    expect(event['requestId'], 1);
    expect(event['text'], 'Hello');
    expect((event['failure'] as Map<String, Object?>)['code'], 'nativeError');
    expect(err.toString(), contains('error: nativeError: decode failed'));
  });

  test('a failed run keeps the partial text in human output', () async {
    engine = ScriptedLlamaEngine(
      tokens: const ['Hel', 'lo'],
      failAfterTokens: true,
      generateFailure: InferenceFailure(
        (b) => b
          ..code = InferenceFailureCode.nativeError
          ..message = 'decode failed',
      ),
    );
    final runner = makeRunner();

    expect(
      await runner.run([
        'bench',
        '--stub',
        '--runs',
        '1',
        '--model',
        '/tmp/demo.gguf',
      ]),
      ExitCodes.failure,
    );

    expect(out.toString(), 'Hello\n');
    expect(err.toString(), contains('error: nativeError: decode failed'));
  });

  test(
    'the first SIGINT cancels and exits with ExitCodes.interrupted',
    () async {
      engine = ScriptedLlamaEngine(
        tokens: const ['tick'],
        tokenInterval: const Duration(milliseconds: 5),
        repeatTokens: true,
      );
      final signals = StreamController<ProcessSignal>();
      addTearDown(signals.close);
      final runner = makeRunner(interrupts: signals.stream);

      final pending = runner.run([
        'bench',
        '--stub',
        '--json',
        '--runs',
        '2',
        '--model',
        '/tmp/demo.gguf',
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      signals.add(ProcessSignal.sigint);

      expect(await pending, ExitCodes.interrupted);
      final event = _lines(out.toString()).single;
      expect(event['type'], 'cancelled');
      expect(event['requestId'], 1);
    },
  );

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

  group('--param', () {
    test('writes typed owners and keeps map values', () async {
      final runner = makeRunner();

      expect(
        await runner.run([
          'bench',
          '--stub',
          '--json',
          '--runs',
          '1',
          '--model',
          '/tmp/demo.gguf',
          '--param',
          'temp=0.2',
          '--param',
          'seed=42',
        ]),
        ExitCodes.ok,
      );

      final params = engine.loadedParams;
      expect(params?.temperature, 0.2);
      expect(params?.params['seed'], '42');
      expect(params?.params.containsKey('temp'), isFalse);
    });

    test('rejects an unknown id before any engine work', () async {
      final runner = makeRunner();

      expect(
        await runner.run([
          'bench',
          '--stub',
          '--runs',
          '1',
          '--param',
          'nope=1',
        ]),
        ExitCodes.usage,
      );

      expect(err.toString(), contains("unknown parameter 'nope'"));
      expect(engine.loadCalls, 0);
    });

    test('rejects a value that disagrees with a typed flag', () async {
      final runner = makeRunner();

      expect(
        await runner.run([
          'bench',
          '--stub',
          '--runs',
          '1',
          '--threads',
          '4',
          '--param',
          'threads=8',
        ]),
        ExitCodes.usage,
      );

      expect(
        err.toString(),
        contains('--threads and --param threads disagree (4 vs 8)'),
      );
      expect(engine.loadCalls, 0);
    });
  });
}
