import 'dart:convert';
import 'dart:io';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

const _defaultArgv = '-c 2048 -t 4 -ngl 0 --temp 0.8 --top-k 40 --top-p 0.95\n';

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
    expect(document, isNotNull);
    final params = document!['params'];
    expect(params, isA<Map<String, Object?>>());
    return params as Map<String, Object?>;
  }

  Future<Map<String, Object?>> storedCatalogParams() async {
    final params = await storedParams();
    final nested = params['params'];
    if (nested == null) {
      return <String, Object?>{};
    }
    expect(nested, isA<Map<String, Object?>>());
    return nested as Map<String, Object?>;
  }

  group('params set --param', () {
    test('each typed owner writes its ModelParams field', () async {
      expect(
        await runner.run([
          'params',
          'set',
          '--param',
          'ctx-size=4096',
          '--param',
          'threads=8',
          '--param',
          'gpu-layers=12',
          '--param',
          'temp=0.7',
          '--param',
          'top-k=33',
          '--param',
          'top-p=0.5',
        ]),
        ExitCodes.ok,
      );

      final params = await storedParams();
      expect(params['contextSize'], 4096);
      expect(params['threads'], 8);
      expect(params['gpuLayers'], 12);
      expect(params['temperature'], 0.7);
      expect(params['topK'], 33);
      expect(params['topP'], 0.5);
      // Typed owners never duplicate the value in the catalog map.
      expect(await storedCatalogParams(), isEmpty);
      expect(out.toString(), contains('temperature: 0.7'));
      expect(out.toString(), isNot(contains('temp:')));
      expect(err.toString(), isEmpty);
    });

    test('chat-template writes the typed field, not the map', () async {
      expect(
        await runner.run(['params', 'set', '--param', 'chat-template=chatml']),
        ExitCodes.ok,
      );

      final params = await storedParams();
      expect(params['chatTemplate'], 'chatml');
      expect(await storedCatalogParams(), isEmpty);
      expect(out.toString(), contains('chatTemplate: chatml'));
      expect(
        out.toString(),
        isNot(contains('chat-template:')),
        reason: 'the map must not carry the typed template',
      );
    });

    test('chat-template=none is stored as the typed value', () async {
      expect(
        await runner.run(['params', 'set', '--param', 'chat-template=none']),
        ExitCodes.ok,
      );

      final params = await storedParams();
      expect(params['chatTemplate'], 'none');
      expect(await storedCatalogParams(), isEmpty);
    });

    test('chat-template= restores the typed default', () async {
      expect(
        await runner.run(['params', 'set', '--param', 'chat-template=chatml']),
        ExitCodes.ok,
      );

      expect(
        await runner.run(['params', 'set', '--param', 'chat-template=']),
        ExitCodes.ok,
      );

      expect((await storedParams())['chatTemplate'], isNull);
      expect(await storedCatalogParams(), isEmpty);
    });

    test('seed, min-p and batch-size stay in the params map', () async {
      expect(
        await runner.run([
          'params',
          'set',
          '--param',
          'seed=42',
          '--param',
          'min-p=0.1',
          '--param',
          'batch-size=512',
        ]),
        ExitCodes.ok,
      );

      expect(await storedCatalogParams(), {
        'batch-size': '512',
        'seed': '42',
        'min-p': '0.1',
      });
      expect(out.toString(), contains("seed: '42'"));
    });

    test('top-k=40 is stored but not listed as modified', () async {
      expect(
        await runner.run(['params', 'set', '--param', 'top-k=40']),
        ExitCodes.ok,
      );
      expect((await storedParams())['topK'], 40);

      out.clear();
      expect(await runner.run(['params', 'get', '--show-modified']), 0);
      expect(out.toString(), isEmpty);
      expect(err.toString(), isEmpty);
    });

    test('id= restores the typed default and removes map values', () async {
      expect(
        await runner.run([
          'params',
          'set',
          '--param',
          'ctx-size=4096',
          '--param',
          'seed=42',
        ]),
        ExitCodes.ok,
      );
      expect((await storedParams())['contextSize'], 4096);

      expect(
        await runner.run([
          'params',
          'set',
          '--param',
          'ctx-size=',
          '--param',
          'seed=',
        ]),
        ExitCodes.ok,
      );

      expect((await storedParams())['contextSize'], 2048);
      expect(await storedCatalogParams(), isEmpty);
    });

    test('repeating a non-repeatable id is a usage error', () async {
      expect(
        await runner.run([
          'params',
          'set',
          '--param',
          'seed=1',
          '--param',
          'seed=2',
        ]),
        ExitCodes.usage,
      );

      expect(err.toString(), contains("'seed' is not repeatable"));
      expect(await storedDocument(), isNull);
    });

    test('a bare id is rejected for a non-boolean', () async {
      expect(
        await runner.run(['params', 'set', '--param', 'seed']),
        ExitCodes.usage,
      );

      expect(
        err.toString(),
        contains("invalid value for --param: 'seed' is not a boolean"),
      );
      expect(await storedDocument(), isNull);
    });

    test('an unknown id exits 2 and leaves the file untouched', () async {
      expect(await runner.run(['params', 'set', '--param', 'seed=7']), 0);
      final before = await storedDocument();

      out.clear();
      expect(
        await runner.run(['params', 'set', '--param', 'nope=1']),
        ExitCodes.usage,
      );

      expect(
        err.toString(),
        contains("unknown parameter 'nope' (run `llamapulse params catalog`)"),
      );
      expect(await storedDocument(), before);
      expect(out.toString(), isEmpty);
    });

    test('an unsupported id exits 2 and leaves the file untouched', () async {
      expect(
        await runner.run([
          'params',
          'set',
          '--param',
          'server-base=http://localhost:9931',
        ]),
        ExitCodes.usage,
      );

      expect(err.toString(), contains("'server-base' is not supported"));
      expect(await storedDocument(), isNull);
    });

    test('a server-only id exits 2 with the validator message', () async {
      expect(
        await runner.run(['params', 'set', '--param', 'cont-batching=true']),
        ExitCodes.usage,
      );

      expect(
        err.toString(),
        contains("'cont-batching' is not available for embedded"),
      );
      expect(await storedDocument(), isNull);
    });

    test('a conflicting typed flag exits 2', () async {
      expect(
        await runner.run([
          'params',
          'set',
          '--temperature',
          '0.5',
          '--param',
          'temp=0.7',
        ]),
        ExitCodes.usage,
      );

      expect(
        err.toString(),
        contains('error: --temperature and --param temp disagree (0.5 vs 0.7)'),
      );
      expect(await storedDocument(), isNull);
    });

    test('an agreeing typed flag is accepted', () async {
      expect(
        await runner.run([
          'params',
          'set',
          '--temperature',
          '0.70',
          '--param',
          'temp=0.7',
        ]),
        ExitCodes.ok,
      );

      expect((await storedParams())['temperature'], 0.7);
      expect(await storedCatalogParams(), isEmpty);
    });

    test('--reset cannot be combined with --param', () async {
      expect(
        await runner.run(['params', 'set', '--reset', '--param', 'temp=0.7']),
        ExitCodes.usage,
      );

      expect(err.toString(), contains('--reset cannot be combined'));
      expect(await storedDocument(), isNull);
    });
  });

  group('params get --show-modified', () {
    test('text lists the typed chat template', () async {
      expect(
        await runner.run(['params', 'set', '--param', 'chat-template=chatml']),
        ExitCodes.ok,
      );

      out.clear();
      expect(await runner.run(['params', 'get', '--show-modified']), 0);

      expect(out.toString(), 'chat-template: chatml\n');
    });

    test('text lists only ids that differ from the defaults', () async {
      expect(
        await runner.run([
          'params',
          'set',
          '--param',
          'seed=42',
          '--param',
          'temp=0.7',
          '--param',
          'top-k=40',
        ]),
        ExitCodes.ok,
      );

      out.clear();
      expect(await runner.run(['params', 'get', '--show-modified']), 0);

      expect(out.toString(), 'seed: 42\ntemp: 0.7\n');
    });

    test('--json keeps the document and adds modified', () async {
      expect(
        await runner.run(['params', 'set', '--param', 'seed=42']),
        ExitCodes.ok,
      );

      out.clear();
      expect(await runner.run(['params', 'get', '--json']), 0);

      final object = jsonDecode(out.toString().trim()) as Map<String, Object?>;
      expect(object['schemaVersion'], 1);
      expect(object['modified'], ['seed']);
      final params = object['params']! as Map<String, Object?>;
      expect(params['contextSize'], 2048);
      expect(params['params'], {'seed': '42'});
    });
  });

  group('params export', () {
    test('prints the default llama-cli argv without writing', () async {
      expect(await runner.run(['params', 'export']), ExitCodes.ok);

      expect(out.toString(), _defaultArgv);
      expect(err.toString(), isEmpty);
      expect(await storedDocument(), isNull);
    });

    test('appends generic parameters in catalog order', () async {
      expect(
        await runner.run([
          'params',
          'set',
          '--param',
          'batch-size=512',
          '--param',
          'seed=42',
          '--param',
          'min-p=0.1',
          '--param',
          'chat-template={{prompt}}',
        ]),
        ExitCodes.ok,
      );

      // The template is typed, so it must not also land in the map.
      expect((await storedParams())['chatTemplate'], '{{prompt}}');
      expect(await storedCatalogParams(), isNot(contains('chat-template')));

      out.clear();
      expect(await runner.run(['params', 'export']), ExitCodes.ok);

      expect(
        out.toString(),
        '-c 2048 -t 4 -ngl 0 --temp 0.8 --top-k 40 --top-p 0.95 '
        '-b 512 --seed 42 --min-p 0.1 --chat-template {{prompt}}\n',
      );
    });

    test('--param overrides the stored value for this run only', () async {
      expect(await runner.run(['params', 'set', '--param', 'seed=7']), 0);
      final before = await storedDocument();

      out.clear();
      expect(
        await runner.run(['params', 'export', '--param', 'temp=0.2']),
        ExitCodes.ok,
      );

      expect(
        out.toString(),
        '-c 2048 -t 4 -ngl 0 --temp 0.2 --top-k 40 --top-p 0.95 --seed 7\n',
      );
      expect(await storedDocument(), before);
    });

    test('--json prints the export object', () async {
      expect(
        await runner.run(['params', 'export', '--json', '--param', 'seed=42']),
        ExitCodes.ok,
      );

      expect(jsonDecode(out.toString().trim()), {
        'schemaVersion': 1,
        'type': 'paramsExport',
        'argv': [
          '-c',
          '2048',
          '-t',
          '4',
          '-ngl',
          '0',
          '--temp',
          '0.8',
          '--top-k',
          '40',
          '--top-p',
          '0.95',
          '--seed',
          '42',
        ],
      });
    });

    test('an unsupported id exits 2 and prints nothing', () async {
      expect(
        await runner.run(['params', 'export', '--param', 'nope=1']),
        ExitCodes.usage,
      );

      expect(err.toString(), contains("unknown parameter 'nope'"));
      expect(out.toString(), isEmpty);
    });

    test('a model path is emitted first', () async {
      expect(
        await runner.run([
          'params',
          'set',
          '--model-path',
          '/models/model.gguf',
        ]),
        ExitCodes.ok,
      );

      out.clear();
      expect(await runner.run(['params', 'export']), ExitCodes.ok);

      expect(
        out.toString(),
        startsWith('-m /models/model.gguf -c 2048 -t 4 -ngl 0'),
      );
    });
  });
}
