import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

import 'support/scripted_llama_engine.dart';

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

  LlamaPulseCommandRunner makeRunner({
    bool useDefaultEngine = false,
    LlamaEngine Function()? engineFactory,
    Stream<List<int>>? stdin,
    Stream<ProcessSignal>? interrupts,
    ConfigStore? configStore,
  }) => LlamaPulseCommandRunner(
    CliServices(
      paths: const AppPaths(configDirectory: '/config/llamapulse'),
      configStore: configStore ?? store,
      out: out,
      err: err,
      stdin: stdin,
      interrupts: interrupts,
      engineFactory: useDefaultEngine ? null : (engineFactory ?? () => engine),
    ),
  );

  test('without --stub exits 1 and reports engineUnavailable', () async {
    final runner = makeRunner();

    final code = await runner.run([
      'run',
      '--model',
      '/tmp/demo.gguf',
      '--prompt',
      'hi',
    ]);

    expect(code, ExitCodes.failure);
    expect(out.toString(), isEmpty);
    expect(
      err.toString(),
      'error: engineUnavailable: the native session is unavailable; '
      'pass --stub\n',
    );
    expect(engine.loadCalls, 0);
    expect(engine.generateCalls, 0);
  });

  test('without --stub emits one failed object in --json mode', () async {
    final runner = makeRunner();

    expect(
      await runner.run([
        'run',
        '--json',
        '--model',
        '/tmp/demo.gguf',
        '--prompt',
        'hi',
      ]),
      ExitCodes.failure,
    );

    final event = _lines(out.toString()).single;
    expect(event['type'], 'failed');
    expect(event['requestId'], 0);
    expect(event['schemaVersion'], 1);
    expect(event['text'], '');
    final failure = event['failure'] as Map<String, Object?>;
    expect(failure['code'], 'engineUnavailable');
    expect(failure['message'], contains('pass --stub'));
    expect(err.toString(), contains('error: engineUnavailable:'));
  });

  test('without --stub emits one failed object in --stream mode', () async {
    final runner = makeRunner();

    expect(
      await runner.run([
        'run',
        '--stream',
        '--model',
        '/tmp/demo.gguf',
        '--prompt',
        'hi',
      ]),
      ExitCodes.failure,
    );

    final event = _lines(out.toString()).single;
    expect(event['type'], 'failed');
    expect(event['requestId'], 0);
    expect(
      (event['failure'] as Map<String, Object?>)['code'],
      'engineUnavailable',
    );
  });

  test('--stub streams text to stdout and a summary to stderr', () async {
    final runner = makeRunner();

    expect(
      await runner.run([
        'run',
        '--stub',
        '--model',
        '/tmp/demo.gguf',
        '--prompt',
        'hi',
      ]),
      ExitCodes.ok,
    );

    expect(out.toString(), 'Hello world\n');
    expect(err.toString(), contains('tokens: 2'));
    expect(err.toString(), contains('tok/s: 100.00'));
    expect(err.toString(), contains('prompt ms: 10'));
    expect(out.toString(), isNot(contains('tokens:')));
    expect(engine.loadCalls, 1);
    expect(engine.generateCalls, 1);
    expect(engine.disposeCalls, 1);
    expect(engine.loadedParams?.modelPath, '/tmp/demo.gguf');
    expect(engine.loadedParams?.maxTokens, 256);
    final request = engine.generateRequests.single;
    expect(request.requestId, 1);
    expect(request.prompt, 'hi');
  });

  test('--stream emits parseable NDJSON from started to completed', () async {
    final runner = makeRunner();

    expect(
      await runner.run([
        'run',
        '--stub',
        '--stream',
        '--model',
        '/tmp/demo.gguf',
        '--prompt',
        'hi',
      ]),
      ExitCodes.ok,
    );

    final events = _lines(out.toString());
    expect(events.first['type'], 'started');
    expect(events.last['type'], 'completed');
    expect(events.every((event) => event['schemaVersion'] == 1), isTrue);
    expect(events.every((event) => event['requestId'] == 1), isTrue);
    final tokenText = events
        .where((event) => event['type'] == 'token')
        .map((event) => event['text'])
        .join();
    expect(tokenText, 'Hello world');
    expect(events.last['text'], tokenText);
    expect(events.last['metrics'], isA<Map<String, Object?>>());
  });

  test('--json emits exactly one terminal object', () async {
    final runner = makeRunner();

    expect(
      await runner.run([
        'run',
        '--stub',
        '--json',
        '--model',
        '/tmp/demo.gguf',
        '--prompt',
        'hi',
      ]),
      ExitCodes.ok,
    );

    final event = _lines(out.toString()).single;
    expect(event['type'], 'completed');
    expect(event['requestId'], 1);
    expect(event['text'], 'Hello world');
    final metrics = event['metrics'] as Map<String, Object?>;
    expect(metrics['generatedTokenCount'], 2);
    expect(metrics['tokensPerSecond'], 100.0);
  });

  test('--prompt and --file together is a usage error', () async {
    final runner = makeRunner();

    expect(
      await runner.run([
        'run',
        '--stub',
        '--model',
        '/tmp/demo.gguf',
        '--prompt',
        'hi',
        '--file',
        '-',
      ]),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('cannot be combined'));
    expect(engine.loadCalls, 0);
  });

  test('neither --prompt nor --file is a usage error', () async {
    final runner = makeRunner();

    expect(
      await runner.run(['run', '--stub', '--model', '/tmp/demo.gguf']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('--prompt or --file'));
    expect(engine.loadCalls, 0);
  });

  test('rejects --prompt with --file before reading stdin', () async {
    final stdin = StreamController<List<int>>();
    addTearDown(() {
      stdin.close();
    });
    final runner = makeRunner(stdin: stdin.stream);

    expect(
      await runner
          .run([
            'run',
            '--stub',
            '--model',
            '/tmp/demo.gguf',
            '--prompt',
            'hi',
            '--file',
            '-',
          ])
          .timeout(const Duration(seconds: 2)),
      ExitCodes.usage,
    );

    expect(stdin.hasListener, isFalse);
    expect(err.toString(), contains('cannot be combined'));
  });

  test('--file - is never read for an invocation without --stub', () async {
    final stdin = StreamController<List<int>>();
    addTearDown(() {
      stdin.close();
    });
    final runner = makeRunner(stdin: stdin.stream);

    expect(
      await runner
          .run(['run', '--model', '/tmp/demo.gguf', '--file', '-'])
          .timeout(const Duration(seconds: 2)),
      ExitCodes.failure,
    );

    expect(stdin.hasListener, isFalse);
    expect(err.toString(), contains('native session is unavailable'));
  });

  test('--file - is never read when the model path is missing', () async {
    final stdin = StreamController<List<int>>();
    addTearDown(() {
      stdin.close();
    });
    final runner = makeRunner(stdin: stdin.stream);

    expect(
      await runner
          .run(['run', '--stub', '--file', '-'])
          .timeout(const Duration(seconds: 2)),
      ExitCodes.usage,
    );

    expect(stdin.hasListener, isFalse);
    expect(err.toString(), contains('model path is required'));
  });

  test('invalid UTF-8 in --file is a usage error', () async {
    final directory = Directory.systemTemp.createTempSync('llamapulse_utf8');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/prompt.txt')
      ..writeAsBytesSync(const [0xff, 0xfe, 0xfd]);
    final runner = makeRunner();

    expect(
      await runner.run([
        'run',
        '--stub',
        '--model',
        '/tmp/demo.gguf',
        '--file',
        file.path,
      ]),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('cannot decode --file'));
    expect(engine.loadCalls, 0);
  });

  test('a non-numeric --threads is a usage error', () async {
    final runner = makeRunner();

    expect(
      await runner.run([
        'run',
        '--stub',
        '--model',
        '/tmp/demo.gguf',
        '--prompt',
        'hi',
        '--threads',
        'abc',
      ]),
      ExitCodes.usage,
    );

    expect(err.toString(), contains("invalid value for --threads: 'abc'"));
    expect(engine.loadCalls, 0);
  });

  test('a blank model path is a usage error', () async {
    final runner = makeRunner();

    expect(
      await runner.run(['run', '--stub', '--model', '   ', '--prompt', 'hi']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('model path is required'));
    expect(engine.loadCalls, 0);
  });

  test('--file - reads the prompt from the injected stdin', () async {
    final runner = makeRunner(
      stdin: Stream<List<int>>.value(utf8.encode('from stdin')),
    );

    expect(
      await runner.run([
        'run',
        '--stub',
        '--model',
        '/tmp/demo.gguf',
        '--file',
        '-',
      ]),
      ExitCodes.ok,
    );

    expect(engine.generateRequests.single.prompt, 'from stdin');
    expect(engine.disposeCalls, 1);
  });

  test('an engine load failure exits 1 with a failed object', () async {
    engine = ScriptedLlamaEngine(
      loadFailure: InferenceFailure(
        (b) => b
          ..code = InferenceFailureCode.modelNotFound
          ..message = 'missing model',
      ),
    );
    final runner = makeRunner();

    expect(
      await runner.run([
        'run',
        '--stub',
        '--json',
        '--model',
        '/tmp/demo.gguf',
        '--prompt',
        'hi',
      ]),
      ExitCodes.failure,
    );

    final event = _lines(out.toString()).single;
    expect(event['type'], 'failed');
    expect(event['requestId'], 1);
    expect((event['failure'] as Map<String, Object?>)['code'], 'modelNotFound');
    expect(err.toString(), contains('error: modelNotFound: missing model'));
    expect(engine.generateCalls, 0);
    expect(engine.disposeCalls, 1);
  });

  test('the first SIGINT cancels and exits 130', () async {
    engine = ScriptedLlamaEngine(
      tokens: const ['tick'],
      tokenInterval: const Duration(milliseconds: 5),
      repeatTokens: true,
    );
    final signals = StreamController<ProcessSignal>();
    addTearDown(signals.close);
    final runner = makeRunner(interrupts: signals.stream);

    final pending = runner.run([
      'run',
      '--stub',
      '--json',
      '--model',
      '/tmp/demo.gguf',
      '--prompt',
      'hi',
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    signals.add(ProcessSignal.sigint);

    expect(await pending, 130);
    expect(engine.cancelCalls, 1);
    expect(engine.cancelledRequestIds, [1]);
    final event = _lines(out.toString()).single;
    expect(event['type'], 'cancelled');
    expect(event['requestId'], 1);
    expect(err.toString(), contains('cancelling...'));
  });

  test('a second SIGINT ends the session with 130', () async {
    engine = ScriptedLlamaEngine(
      tokens: const ['tick'],
      tokenInterval: const Duration(milliseconds: 5),
      honourCancel: false,
      repeatTokens: true,
    );
    final signals = StreamController<ProcessSignal>();
    addTearDown(signals.close);
    final runner = makeRunner(interrupts: signals.stream);

    final pending = runner.run([
      'run',
      '--stub',
      '--json',
      '--model',
      '/tmp/demo.gguf',
      '--prompt',
      'hi',
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    signals.add(ProcessSignal.sigint);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    signals.add(ProcessSignal.sigint);

    expect(await pending, 130);
    expect(engine.cancelCalls, 1);
    final event = _lines(out.toString()).single;
    expect(event['type'], 'cancelled');
  });

  test('the real worker isolate completes through the CLI', () async {
    final runner = makeRunner(useDefaultEngine: true);

    final code = await runner.run([
      'run',
      '--stub',
      '--json',
      '--model',
      '/tmp/demo.gguf',
      '--prompt',
      'hello',
      '--max-tokens',
      '4',
    ]);

    expect(code, ExitCodes.ok);
    final event = _lines(out.toString()).single;
    expect(event['type'], 'completed');
    expect(event['requestId'], 1);
    expect(event['text'], isNotEmpty);
    final metrics = event['metrics'] as Map<String, Object?>;
    expect(metrics['generatedTokenCount'], 4);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
