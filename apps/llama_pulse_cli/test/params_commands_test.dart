import 'dart:convert';
import 'dart:io';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

const _defaultDocument =
    'schemaVersion: 1\n'
    'params:\n'
    "  modelPath: ''\n"
    '  contextSize: 2048\n'
    '  gpuLayers: 0\n'
    '  threads: 4\n'
    '  temperature: 0.8\n'
    '  topP: 0.95\n'
    '  topK: 40\n'
    '  maxTokens: 256\n';

void main() {
  late Directory tempDirectory;
  late InMemoryConfigStore store;
  late StringBuffer out;
  late StringBuffer err;
  late LlamaPulseCommandRunner runner;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('llamapulse_cli_');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    store = InMemoryConfigStore();
    out = StringBuffer();
    err = StringBuffer();
    runner = LlamaPulseCommandRunner(
      CliServices(
        paths: AppPaths(configDirectory: tempDirectory.path),
        configStore: store,
        out: out,
        err: err,
      ),
    );
  });

  Future<Map<String, Object?>?> storedDocument() => store.read('params');

  Future<Map<String, Object?>> storedParams() async {
    final document = await storedDocument();
    final params = document?['params'];
    expect(params, isA<Map<String, Object?>>());
    return params as Map<String, Object?>;
  }

  test('params get prints the default golden document', () async {
    expect(await runner.run(['params', 'get']), ExitCodes.ok);

    expect(out.toString(), _defaultDocument);
    expect(err.toString(), isEmpty);
    expect(await storedDocument(), isNull);
  });

  test('params set writes the updated values', () async {
    expect(
      await runner.run([
        'params',
        'set',
        '--context-size',
        '4096',
        '--temperature',
        '0.5',
      ]),
      ExitCodes.ok,
    );

    final document = await storedDocument();
    expect(document?['schemaVersion'], ModelParams.schemaVersion);
    final params = await storedParams();
    expect(params['contextSize'], 4096);
    expect(params['temperature'], 0.5);
    expect(out.toString(), contains('contextSize: 4096'));
    expect(out.toString(), contains('temperature: 0.5'));
    expect(err.toString(), isEmpty);
  });

  test('params set rejects an out-of-range value without writing', () async {
    expect(
      await runner.run(['params', 'set', '--threads', '0']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('error: threads must be in 1..256'));
    expect(await storedDocument(), isNull);
    expect(out.toString(), isEmpty);
  });

  test('params set rejects a non-numeric value', () async {
    expect(
      await runner.run(['params', 'set', '--temperature', 'abc']),
      ExitCodes.usage,
    );

    expect(
      err.toString(),
      contains("error: invalid value for --temperature: 'abc'"),
    );
    expect(await storedDocument(), isNull);
  });

  test('params set --reset restores the defaults', () async {
    expect(
      await runner.run(['params', 'set', '--context-size', '4096']),
      ExitCodes.ok,
    );
    expect(await storedParams(), containsPair('contextSize', 4096));

    out.clear();
    expect(await runner.run(['params', 'set', '--reset']), ExitCodes.ok);

    final params = await storedParams();
    expect(params['contextSize'], 2048);
    expect(params['modelPath'], '');
    expect(out.toString(), _defaultDocument);
  });

  test('params set --reset with a value option is a usage error', () async {
    expect(
      await runner.run(['params', 'set', '--reset', '--threads', '2']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('error: --reset cannot be combined'));
    expect(await storedDocument(), isNull);
  });

  test('params get --json prints one parseable object', () async {
    expect(await runner.run(['params', 'get', '--json']), ExitCodes.ok);

    final lines = out.toString().split('\n').where((line) => line.isNotEmpty);
    expect(lines.length, 1);
    expect(jsonDecode(out.toString().trim()), {
      'schemaVersion': 1,
      'params': {
        'modelPath': '',
        'contextSize': 2048,
        'gpuLayers': 0,
        'threads': 4,
        'temperature': 0.8,
        'topP': 0.95,
        'topK': 40,
        'maxTokens': 256,
      },
    });
  });

  test('a model path with spaces round-trips', () async {
    const modelPath = '/models/my model.gguf';

    expect(
      await runner.run(['params', 'set', '--model-path', modelPath]),
      ExitCodes.ok,
    );
    expect(await storedParams(), containsPair('modelPath', modelPath));
    expect(out.toString(), contains('modelPath: $modelPath'));

    out.clear();
    expect(await runner.run(['params', 'get', '--json']), ExitCodes.ok);
    final decoded = jsonDecode(out.toString().trim()) as Map<String, Object?>;
    final params = decoded['params'] as Map<String, Object?>;
    expect(params['modelPath'], modelPath);
  });
}
