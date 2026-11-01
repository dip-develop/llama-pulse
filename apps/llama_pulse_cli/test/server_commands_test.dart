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

  Future<Map<String, Object?>> storedParams() async {
    final server = await storedServer();
    final params = server['params'] ?? <String, Object?>{};
    expect(params, isA<Map<String, Object?>>());
    return params as Map<String, Object?>;
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

  test('server set --param stores typed canonical values', () async {
    final code = await runner.run([
      'server',
      'set',
      '--param',
      'top-k=33',
      '--param',
      'cont-batching',
      '--param',
      'cont-batching=true',
      '--param',
      'cache-type-k=q8_0',
      '--param',
      'grammar-file=/tmp/grammar.gbnf',
    ]);

    expect(code, ExitCodes.ok);
    final params = await storedParams();
    expect(params['top-k'], '33');
    expect(params['cont-batching'], 'true');
    expect(params['cache-type-k'], 'q8_0');
    expect(params['grammar-file'], '/tmp/grammar.gbnf');
    expect(err.toString(), isEmpty);
  });

  test('server set --param sets a boolean false', () async {
    expect(
      await runner.run(['server', 'set', '--param', 'cont-batching=false']),
      ExitCodes.ok,
    );
    expect((await storedParams())['cont-batching'], 'false');
  });

  test(
    'server set --param accepts a comma list and appends repeatables',
    () async {
      expect(
        await runner.run([
          'server',
          'set',
          '--param',
          'dry-sequence-breaker=a,b',
          '--param',
          'logit-bias=1=+2',
          '--param',
          'logit-bias=3=-4',
        ]),
        ExitCodes.ok,
      );

      final params = await storedParams();
      expect(params['dry-sequence-breaker'], 'a,b');
      expect(params['logit-bias'], '1=+2\n3=-4');
    },
  );

  test(
    'server set --param with an empty value removes the stored id',
    () async {
      expect(
        await runner.run(['server', 'set', '--param', 'top-k=33']),
        ExitCodes.ok,
      );
      expect(await storedParams(), containsPair('top-k', '33'));

      out.clear();
      expect(
        await runner.run(['server', 'set', '--param', 'top-k=']),
        ExitCodes.ok,
      );
      expect((await storedServer())['params'], anyOf(isNull, isEmpty));
    },
  );

  test('server set --param writes an owned id into the typed field', () async {
    expect(
      await runner.run(['server', 'set', '--param', 'threads=8']),
      ExitCodes.ok,
    );

    final server = await storedServer();
    expect(server['threads'], 8);
    // The value is never duplicated in the params map, which is omitted when
    // it is empty.
    expect(server['params'], isNull);
    expect(out.toString(), contains('threads: 8'));
    expect(out.toString(), isNot(contains('params:')));
  });

  test(
    'server set --param rejects an owned id that disagrees with the flag',
    () async {
      expect(
        await runner.run([
          'server',
          'set',
          '--threads',
          '4',
          '--param',
          'threads=8',
        ]),
        ExitCodes.usage,
      );

      expect(
        err.toString(),
        contains('error: --threads and --param threads disagree (4 vs 8)'),
      );
      expect(await storedDocument(), isNull);
    },
  );

  test('server set --param accepts an owned id equal to the flag', () async {
    expect(
      await runner.run([
        'server',
        'set',
        '--threads',
        '8',
        '--param',
        'threads=8',
      ]),
      ExitCodes.ok,
    );

    final server = await storedServer();
    expect(server['threads'], 8);
    expect(server['params'], isNull);
  });

  test('server set --param rejects a managed id without writing', () async {
    expect(
      await runner.run(['server', 'set', '--param', 'metrics=true']),
      ExitCodes.usage,
    );

    expect(
      err.toString(),
      contains("error: 'metrics' is managed by LlamaPulse supervisor"),
    );
    expect(await storedDocument(), isNull);
  });

  test(
    'server set --param rejects an unsupported id without writing',
    () async {
      expect(
        await runner.run([
          'server',
          'set',
          '--param',
          'server-base=http://localhost:9931',
        ]),
        ExitCodes.usage,
      );

      expect(err.toString(), contains("error: 'server-base' is not supported"));
      expect(await storedDocument(), isNull);
    },
  );

  test('server set --param rejects an unknown id without writing', () async {
    expect(
      await runner.run(['server', 'set', '--param', 'nope=1']),
      ExitCodes.usage,
    );

    expect(
      err.toString(),
      contains(
        "error: unknown parameter 'nope' (run `llamapulse params catalog`)",
      ),
    );
    expect(await storedDocument(), isNull);
    expect(out.toString(), isEmpty);
  });

  test('server set --param rejects a bare id for a non-boolean', () async {
    expect(
      await runner.run(['server', 'set', '--param', 'top-k']),
      ExitCodes.usage,
    );

    expect(
      err.toString(),
      contains("invalid value for --param: 'top-k' is not a boolean"),
    );
    expect(await storedDocument(), isNull);
  });

  test('server set rejects --reset combined with --param', () async {
    expect(
      await runner.run(['server', 'set', '--reset', '--param', 'top-k=33']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('--reset cannot be combined'));
    expect(await storedDocument(), isNull);
  });

  test('server get --show-modified prints only changed ids', () async {
    expect(
      await runner.run([
        'server',
        'set',
        '--param',
        'top-k=40',
        '--param',
        'cont-batching=false',
        '--param',
        'threads=8',
      ]),
      ExitCodes.ok,
    );

    out.clear();
    expect(
      await runner.run(['server', 'get', '--show-modified']),
      ExitCodes.ok,
    );

    final text = out.toString();
    expect(text, contains('threads: 8'));
    expect(text, contains('cont-batching: false'));
    // top-k=40 is the catalog default, so the effective value is unchanged.
    expect(text, isNot(contains('top-k')));
    expect(text, isNot(contains('modelPath')));
    expect(
      text.split('\n').where((line) => line.isNotEmpty),
      everyElement(matches(RegExp(r'^[a-z0-9-]+: .+$'))),
    );
  });

  test('server get --json always includes params and modified', () async {
    expect(
      await runner.run(['server', 'set', '--param', 'threads=8']),
      ExitCodes.ok,
    );

    out.clear();
    expect(await runner.run(['server', 'get', '--json']), ExitCodes.ok);

    final object = jsonDecode(out.toString().trim()) as Map<String, Object?>;
    expect(object['schemaVersion'], 1);
    expect(object['params'], isA<Map<String, Object?>>());
    expect(object['modified'], contains('threads'));
    final server = object['server']! as Map<String, Object?>;
    expect(server['threads'], 8);
  });

  test('server help takes typed flag text and the --param pointer from '
      'the catalog', () {
    final usage =
        runner.commands['server']!.subcommands['set']!.argParser.usage;
    expect(usage, contains('TCP port llama-server listens on.'));
    expect(usage, contains('params catalog'));
    expect(usage, contains('params describe'));
  });
}
