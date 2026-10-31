import 'dart:convert';
import 'dart:io';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDirectory;
  late InMemoryConfigStore store;
  late StringBuffer out;
  late StringBuffer err;
  late LlamaPulseCommandRunner runner;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('llamapulse_server_');
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

  Future<Map<String, Object?>?> storedDocument() => store.read('server');

  Future<Map<String, Object?>> storedServer() async {
    final document = await storedDocument();
    expect(document, isNotNull);
    final server = document!['server'];
    expect(server, isA<Map<String, Object?>>());
    return server as Map<String, Object?>;
  }

  test('server get prints the default document without writing', () async {
    expect(await runner.run(['server', 'get']), ExitCodes.ok);

    expect(out.toString(), startsWith('schemaVersion: 1\nserver:\n'));
    expect(out.toString(), contains("modelPath: ''"));
    expect(out.toString(), contains('host: 127.0.0.1'));
    expect(out.toString(), contains('port: 8080'));
    expect(err.toString(), isEmpty);
    expect(await storedDocument(), isNull);
  });

  test('server set writes every value flag', () async {
    final code = await runner.run([
      'server',
      'set',
      '--model-path',
      '/models/x.gguf',
      '--host',
      '0.0.0.0',
      '--port',
      '8099',
      '--context-size',
      '8192',
      '--threads',
      '8',
      '--gpu-layers',
      '20',
      '--parallel',
      '4',
      '--alias',
      'test-alias',
      '--api-key',
      'secret',
      '--flash-attn',
      'on',
      '--mlock',
      '--no-mmap',
      '--extra-arg=--foo',
      '--extra-arg=bar',
      '--binary',
      '/opt/llama-server',
      '--startup-timeout',
      '30',
    ]);

    expect(code, ExitCodes.ok);
    final server = await storedServer();
    expect(server['modelPath'], '/models/x.gguf');
    expect(server['host'], '0.0.0.0');
    expect(server['port'], 8099);
    expect(server['contextSize'], 8192);
    expect(server['threads'], 8);
    expect(server['gpuLayers'], 20);
    expect(server['parallelSlots'], 4);
    expect(server['modelAlias'], 'test-alias');
    expect(server['apiKey'], 'secret');
    expect(server['flashAttention'], 'on');
    expect(server['mlock'], isTrue);
    expect(server['mmap'], isFalse);
    expect(server['extraArgs'], ['--foo', 'bar']);
    expect(server['binaryPath'], '/opt/llama-server');
    expect(server['startupTimeoutSeconds'], 30);
    expect(out.toString(), contains('modelPath: /models/x.gguf'));
    expect(err.toString(), isEmpty);
  });

  test('server set flips booleans both ways', () async {
    expect(
      await runner.run(['server', 'set', '--mlock', '--no-mmap']),
      ExitCodes.ok,
    );
    var server = await storedServer();
    expect(server['mlock'], isTrue);
    expect(server['mmap'], isFalse);

    expect(
      await runner.run(['server', 'set', '--no-mlock', '--mmap']),
      ExitCodes.ok,
    );
    server = await storedServer();
    expect(server['mlock'], isFalse);
    expect(server['mmap'], isTrue);
  });

  test('server set --extra-arg replaces the stored list', () async {
    expect(
      await runner.run(['server', 'set', '--extra-arg=one', '--extra-arg=two']),
      ExitCodes.ok,
    );
    expect((await storedServer())['extraArgs'], ['one', 'two']);

    expect(
      await runner.run(['server', 'set', '--extra-arg=three']),
      ExitCodes.ok,
    );
    expect((await storedServer())['extraArgs'], ['three']);
  });

  test('server set --reset restores the defaults', () async {
    expect(await runner.run(['server', 'set', '--port', '9000']), ExitCodes.ok);
    expect((await storedServer())['port'], 9000);

    out.clear();
    expect(await runner.run(['server', 'set', '--reset']), ExitCodes.ok);
    expect((await storedServer())['port'], 8080);
    expect((await storedServer())['modelPath'], '');
    expect(out.toString(), contains('port: 8080'));
  });

  test('server set rejects --reset combined with a value flag', () async {
    expect(
      await runner.run(['server', 'set', '--reset', '--port', '9000']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('--reset cannot be combined'));
    expect(await storedDocument(), isNull);
    expect(out.toString(), isEmpty);
  });

  test('server set rejects an invalid port without writing', () async {
    expect(
      await runner.run(['server', 'set', '--port', '70000']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('error: port must be in 1..65535'));
    expect(await storedDocument(), isNull);
  });

  test(
    'server set leaves a previous document untouched on invalid input',
    () async {
      expect(
        await runner.run(['server', 'set', '--port', '8099']),
        ExitCodes.ok,
      );
      final before = await storedDocument();

      expect(
        await runner.run(['server', 'set', '--context-size', '10']),
        ExitCodes.usage,
      );
      expect(await storedDocument(), before);
    },
  );

  test('server set rejects a non-numeric value', () async {
    expect(
      await runner.run(['server', 'set', '--threads', 'many']),
      ExitCodes.usage,
    );
    expect(
      err.toString(),
      contains("error: invalid value for --threads: 'many'"),
    );
    expect(await storedDocument(), isNull);
  });

  test('server set rejects an invalid flash-attention mode', () async {
    expect(
      await runner.run(['server', 'set', '--flash-attn', 'sometimes']),
      ExitCodes.usage,
    );
    expect(
      err.toString(),
      contains("error: invalid value for --flash-attn: 'sometimes'"),
    );
  });

  test('server get --json prints one document object', () async {
    expect(await runner.run(['server', 'get', '--json']), ExitCodes.ok);

    final lines = out.toString().split('\n').where((line) => line.isNotEmpty);
    expect(lines, hasLength(1));
    final object = jsonDecode(lines.single) as Map<String, Object?>;
    expect(object['schemaVersion'], 1);
    expect(object['server'], isA<Map<String, Object?>>());
    expect((object['server']! as Map<String, Object?>)['port'], 8080);
  });

  test('server set --json prints one document object', () async {
    expect(
      await runner.run(['server', 'set', '--port', '8099', '--json']),
      ExitCodes.ok,
    );

    final lines = out.toString().split('\n').where((line) => line.isNotEmpty);
    expect(lines, hasLength(1));
    final object = jsonDecode(lines.single) as Map<String, Object?>;
    expect((object['server']! as Map<String, Object?>)['port'], 8099);
  });

  test('server get echoes the stored document exactly', () async {
    await runner.run(['server', 'set', '--port', '8099', '--alias', 'echo']);

    final expected = YamlEncoder.encode((await storedDocument())!);
    out.clear();
    expect(await runner.run(['server', 'get']), ExitCodes.ok);
    expect(out.toString(), expected);
  });

  test('--model is an alias of --model-path', () async {
    expect(
      await runner.run(['server', 'set', '--model', '/models/alias.gguf']),
      ExitCodes.ok,
    );
    expect((await storedServer())['modelPath'], '/models/alias.gguf');
  });
}
