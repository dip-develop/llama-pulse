import 'dart:convert';
import 'dart:io';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

const _parameterKeys = [
  'id',
  'displayName',
  'flags',
  'negatedFlag',
  'type',
  'arity',
  'defaultValue',
  'min',
  'max',
  'allowed',
  'itemType',
  'repeatable',
  'group',
  'surfaces',
  'exposure',
  'owner',
  'managedBy',
  'envVar',
  'advanced',
  'deprecated',
  'replacement',
  'requiresExistingPath',
  'warning',
  'summary',
  'description',
  'reason',
];

void main() {
  late Directory tempDirectory;
  late StringBuffer out;
  late StringBuffer err;
  late LlamaPulseCommandRunner runner;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'llamapulse_catalog_',
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

  Map<String, Object?> readJson() =>
      jsonDecode(out.toString().trim()) as Map<String, Object?>;

  List<String> ids(Map<String, Object?> catalog) => [
    for (final entry in catalog['parameters']! as List<Object?>)
      (entry! as Map<String, Object?>)['id']! as String,
  ];

  test('text output is grouped and hides unsupported entries', () async {
    expect(await runner.run(['params', 'catalog']), ExitCodes.ok);

    final text = out.toString();
    expect(text, contains('Model & context (essentials)'));
    expect(text, contains('Sampling & penalties (sampling)'));
    expect(text, contains('top-k'));
    expect(text, contains('--top-k'));
    expect(text, contains('default=40'));
    expect(text, contains('configurable'));
    // 138 unsupported/removed entries are hidden by default.
    expect(text, isNot(contains('server-base')));
    expect(text, isNot(contains('defrag-thold')));
    expect(err.toString(), isEmpty);
  });

  test('--include-unsupported adds unsupported and removed entries', () async {
    expect(
      await runner.run(['params', 'catalog', '--include-unsupported']),
      ExitCodes.ok,
    );

    final text = out.toString();
    expect(text, contains('Not available (unsupported)'));
    expect(text, contains('server-base'));
    expect(text, contains('defrag-thold'));
    expect(text, contains('removed'));
  });

  test('--group filters to one group', () async {
    expect(
      await runner.run(['params', 'catalog', '--group', 'sampling']),
      ExitCodes.ok,
    );

    final text = out.toString();
    expect(text, contains('Sampling & penalties (sampling)'));
    expect(text, contains('top-k'));
    expect(text, isNot(contains('essentials')));
    expect(text, isNot(contains('ctx-size')));
  });

  test('--group is repeatable and rejects an unknown id', () async {
    expect(
      await runner.run([
        'params',
        'catalog',
        '--group',
        'sampling',
        '--group',
        'threads',
      ]),
      ExitCodes.ok,
    );
    expect(out.toString(), contains('top-k'));
    expect(out.toString(), contains('Threads & CPU (threads)'));
    expect(out.toString(), isNot(contains('essentials')));

    out.clear();
    expect(
      await runner.run(['params', 'catalog', '--group', 'nope']),
      ExitCodes.usage,
    );
    expect(err.toString(), contains("error: unknown parameter group 'nope'"));
  });

  test('--surface embedded lists exactly the ten embedded ids', () async {
    expect(
      await runner.run([
        'params',
        'catalog',
        '--surface',
        'embedded',
        '--json',
      ]),
      ExitCodes.ok,
    );

    final catalog = readJson();
    expect(
      ids(catalog),
      unorderedEquals([
        'threads',
        'ctx-size',
        'batch-size',
        'seed',
        'temp',
        'top-k',
        'top-p',
        'min-p',
        'gpu-layers',
        'chat-template',
      ]),
    );
    expect(catalog['count'], 10);
    expect(catalog['surface'], 'embedded');
  });

  test(
    '--surface server excludes unsupported entries and the flag adds none',
    () async {
      expect(
        await runner.run([
          'params',
          'catalog',
          '--surface',
          'server',
          '--json',
        ]),
        ExitCodes.ok,
      );
      final catalog = readJson();
      expect(catalog['count'], 224);
      expect(catalog['parameters'], hasLength(224));
      expect(ids(catalog), contains('top-k'));
      expect(ids(catalog), isNot(contains('server-base')));
    },
  );

  test('json output has the documented shape and key set', () async {
    expect(await runner.run(['params', 'catalog', '--json']), ExitCodes.ok);

    final catalog = readJson();
    expect(catalog.keys, [
      'schemaVersion',
      'type',
      'surface',
      'upstreamTag',
      'count',
      'groups',
      'parameters',
    ]);
    expect(catalog['schemaVersion'], 1);
    expect(catalog['type'], 'parameterCatalog');
    expect(catalog['surface'], 'all');
    expect(catalog['upstreamTag'], 'v0.8.0');
    expect(catalog['count'], 224);
    expect(catalog['parameters'], hasLength(224));

    final groups = catalog['groups']! as List<Object?>;
    expect(groups, isNotEmpty);
    expect((groups.first! as Map<String, Object?>).keys, [
      'id',
      'name',
      'order',
      'defaultOpen',
    ]);

    final topK = (catalog['parameters']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .firstWhere((parameter) => parameter['id'] == 'top-k');
    expect(topK.keys, _parameterKeys);
    expect(topK['type'], 'int');
    expect(topK['defaultValue'], 40);
    expect(topK['surfaces'], ['server', 'embedded']);
    expect(topK['exposure'], 'configurable');
    expect(topK['summary'], 'Top-k sampling cutoff.');
  });

  test(
    'json count matches the number of parameters with unsupported',
    () async {
      expect(
        await runner.run([
          'params',
          'catalog',
          '--include-unsupported',
          '--json',
        ]),
        ExitCodes.ok,
      );

      final catalog = readJson();
      expect(catalog['count'], 362);
      expect(catalog['parameters'], hasLength(362));
      expect(ids(catalog), contains('server-base'));
      expect(ids(catalog), contains('defrag-thold'));
    },
  );

  test('--surface all with an unsupported group filter is empty', () async {
    expect(
      await runner.run([
        'params',
        'catalog',
        '--group',
        'unsupported',
        '--json',
      ]),
      ExitCodes.ok,
    );

    final catalog = readJson();
    expect(catalog['count'], 0);
    expect(catalog['groups'], isEmpty);
  });
}
