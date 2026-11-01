import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<Directory> createTempDirectory() async {
  final directory = await Directory.systemTemp.createTemp(
    'llama_pulse_server_',
  );
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return directory;
}

ServerConfig _config() => ServerConfig.defaults().copyWith(
  modelPath: '/models/llama-3.2-3b-instruct.Q4_K_M.gguf',
  host: '0.0.0.0',
  port: 9090,
  contextSize: 8192,
  threads: 8,
  gpuLayers: 12,
  parallelSlots: 2,
  modelAlias: 'local llama',
  apiKey: 'secret token',
  flashAttention: ServerFlashAttention.on,
  mlock: true,
  mmap: false,
  extraArgs: BuiltList<String>(['--future-flag', '--other-flag']),
  binaryPath: '/opt/llama.cpp/llama-server',
  startupTimeoutSeconds: 60,
);

void main() {
  late Directory directory;
  late YamlServerConfigRepository repository;
  late File serverFile;

  setUp(() async {
    directory = await createTempDirectory();
    repository = YamlServerConfigRepository(
      store: YamlFileConfigStore(directory: directory.path),
      serializers: serializers,
    );
    serverFile = File(p.join(directory.path, 'server.yaml'));
  });

  test('toDocument starts with the schema version and a server mapping', () {
    final document = repository.toDocument(ServerConfig.defaults());

    expect(document.keys.toList(), ['schemaVersion', 'server']);
    expect(document['schemaVersion'], 1);

    final encoded = YamlEncoder.encode(document);
    final lines = encoded.split('\n');
    expect(lines.first, 'schemaVersion: 1');
    expect(lines[1], 'server:');
    expect(lines[2], "  modelPath: ''");
  });

  test('save writes the same document toDocument returns', () async {
    await repository.save(_config());

    expect(
      await serverFile.readAsString(),
      YamlEncoder.encode(repository.toDocument(_config())),
    );
  });

  test('round-trips every field', () async {
    await repository.save(_config());

    expect(await repository.load(), _config());
  });

  test('round-trips the defaults', () async {
    await repository.save(ServerConfig.defaults());

    expect(await repository.load(), ServerConfig.defaults());
  });

  test('round-trips extra arguments with spaces and hashes', () async {
    final config = ServerConfig.defaults().copyWith(
      extraArgs: BuiltList<String>([
        '--future-flag',
        '/models/my adapter #1.gguf',
        '--future-scaled=1.0',
      ]),
    );

    await repository.save(config);

    expect(await repository.load(), config);
  });

  test('round-trips an api key with a hash and a quote', () async {
    final config = ServerConfig.defaults().copyWith(apiKey: "it's #1");

    await repository.save(config);

    expect(await repository.load(), config);
  });

  test('load falls back to defaults for a missing document', () async {
    expect(await repository.load(), ServerConfig.defaults());
  });

  test('load falls back to defaults for garbage YAML', () async {
    await serverFile.writeAsString('not: [valid');

    expect(await repository.load(), ServerConfig.defaults());
  });

  test('load falls back to defaults for an unknown schema version', () async {
    await serverFile.writeAsString(
      YamlEncoder.encode(<String, Object?>{
        'schemaVersion': 99,
        'server': repository.toDocument(_config())['server'],
      }),
    );

    expect(await repository.load(), ServerConfig.defaults());
  });

  test('load falls back to defaults when server is not a map', () async {
    await serverFile.writeAsString('schemaVersion: 1\nserver: 5\n');

    expect(await repository.load(), ServerConfig.defaults());
  });

  test('load falls back to defaults when a field is missing', () async {
    await serverFile.writeAsString(
      YamlEncoder.encode(<String, Object?>{
        'schemaVersion': 1,
        'server': <String, Object?>{'modelPath': '/models/x.gguf'},
      }),
    );

    expect(await repository.load(), ServerConfig.defaults());
  });

  test('load ignores unknown extra fields', () async {
    final server = repository.toDocument(_config())['server']!;
    await serverFile.writeAsString(
      YamlEncoder.encode(<String, Object?>{
        'schemaVersion': 1,
        'server': <String, Object?>{
          ...server as Map<String, Object?>,
          'futureField': 'ignored',
        },
      }),
    );

    expect(await repository.load(), _config());
  });

  test('load falls back to defaults when validation fails', () async {
    final server = repository.toDocument(_config())['server']!;
    await serverFile.writeAsString(
      YamlEncoder.encode(<String, Object?>{
        'schemaVersion': 1,
        'server': <String, Object?>{
          ...server as Map<String, Object?>,
          'port': 0,
        },
      }),
    );

    expect(await repository.load(), ServerConfig.defaults());
  });

  test(
    'save rejects invalid configuration without touching the file',
    () async {
      await repository.save(_config());
      final before = await serverFile.readAsString();

      await expectLater(
        repository.save(_config().copyWith(port: 0)),
        throwsA(
          isA<ServerException>().having(
            (error) => error.failure.code,
            'code',
            ServerFailureCode.invalidConfig,
          ),
        ),
      );

      expect(await serverFile.readAsString(), before);
    },
  );

  test('the rejection names every violation', () async {
    try {
      await repository.save(
        ServerConfig.defaults().copyWith(port: 0, threads: 0),
      );
      fail('save should have thrown');
    } on ServerException catch (error) {
      expect(
        error.failure.details,
        ['port must be in 1..65535', 'threads must be in 1..256'].join('\n'),
      );
    }
  });

  test('omits params from the document when the map is empty', () {
    final document = repository.toDocument(ServerConfig.defaults());
    final server = document['server']! as Map<String, Object?>;

    expect(server.containsKey('params'), isFalse);
    expect(YamlEncoder.encode(document), isNot(contains('params:')));
  });

  test('writes params only when the map is non-empty', () {
    final config = _config().copyWith(
      params: BuiltMap<String, String>({'temp': '0.5'}),
    );

    final encoded = YamlEncoder.encode(repository.toDocument(config));

    expect(encoded, contains('\n  params:\n'));
    expect(encoded, contains("\n    temp: '0.5'\n"));
  });

  test('round-trips catalog values', () async {
    final config = _config().copyWith(
      params: BuiltMap<String, String>({
        'temp': '0.5',
        'chat-template': '{{prompt}}',
      }),
    );

    await repository.save(config);

    expect(await repository.load(), config);
  });

  test('normalizes params insertion order before writing', () {
    final first = _config().copyWith(
      params: BuiltMap<String, String>({
        'chat-template': '{{prompt}}',
        'temp': '0.5',
      }),
    );
    final second = _config().copyWith(
      params: BuiltMap<String, String>({
        'temp': '0.5',
        'chat-template': '{{prompt}}',
      }),
    );

    expect(
      YamlEncoder.encode(repository.toDocument(first)),
      YamlEncoder.encode(repository.toDocument(second)),
    );
  });

  test(
    'an old document without params loads and re-saves byte for byte',
    () async {
      final encoded = YamlEncoder.encode(repository.toDocument(_config()));
      expect(encoded, isNot(contains('params:')));
      await serverFile.writeAsString(encoded);

      final loaded = await repository.load();
      await repository.save(loaded);

      expect(await serverFile.readAsString(), encoded);
    },
  );

  test('rejects a managed typed field in params', () async {
    final config = ServerConfig.defaults().copyWith(
      contextSize: 8192,
      params: BuiltMap<String, String>({'ctx-size': '9999'}),
    );

    await expectLater(
      repository.save(config),
      throwsA(
        isA<ServerException>().having(
          (error) => error.failure.details,
          'details',
          "'ctx-size' is managed by ServerConfig",
        ),
      ),
    );
  });
}
