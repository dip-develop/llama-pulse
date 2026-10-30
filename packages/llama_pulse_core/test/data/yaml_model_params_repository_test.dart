import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<Directory> createTempDirectory() async {
  final directory = await Directory.systemTemp.createTemp('llama_pulse_repo_');
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return directory;
}

ModelParams _params() => ModelParams.defaults().copyWith(
  modelPath: '/models/llama-3.2-3b-instruct.Q4_K_M.gguf',
);

void main() {
  late Directory directory;
  late YamlFileConfigStore store;
  late YamlModelParamsRepository repository;
  late File paramsFile;

  setUp(() async {
    directory = await createTempDirectory();
    store = YamlFileConfigStore(directory: directory.path);
    repository = YamlModelParamsRepository(
      store: store,
      serializers: serializers,
    );
    paramsFile = File(p.join(directory.path, 'params.yaml'));
  });

  test('save writes the golden document byte for byte', () async {
    final golden = await File('test/fixtures/params_golden.yaml')
        .readAsString();

    await repository.save(_params());

    expect(await paramsFile.readAsString(), golden);
  });

  test('toDocument encodes to the golden document byte for byte', () async {
    final golden = await File('test/fixtures/params_golden.yaml')
        .readAsString();

    expect(YamlEncoder.encode(repository.toDocument(_params())), golden);
  });

  test('load reads the golden document', () async {
    final golden = await File('test/fixtures/params_golden.yaml')
        .readAsString();
    await paramsFile.writeAsString(golden);

    expect(await repository.load(), _params());
  });

  test('load falls back to defaults for a missing document', () async {
    expect(await repository.load(), ModelParams.defaults());
  });

  test('load falls back to defaults for garbage YAML', () async {
    await paramsFile.writeAsString('not: [valid');

    expect(await repository.load(), ModelParams.defaults());
  });

  test('load falls back to defaults for an unknown schema version', () async {
    await paramsFile.writeAsString('schemaVersion: 99\nparams: {}\n');

    expect(await repository.load(), ModelParams.defaults());
  });

  test('load falls back to defaults when params is not a map', () async {
    await paramsFile.writeAsString('schemaVersion: 1\nparams: 5\n');

    expect(await repository.load(), ModelParams.defaults());
  });

  test('load ignores unknown extra fields', () async {
    await paramsFile.writeAsString(
      YamlEncoder.encode(<String, Object?>{
        'schemaVersion': 1,
        'params': <String, Object?>{
          'modelPath': '/models/x.gguf',
          'contextSize': 1024,
          'gpuLayers': 1,
          'threads': 2,
          'temperature': 0.5,
          'topP': 0.9,
          'topK': 10,
          'maxTokens': 64,
          'futureField': 'ignored',
        },
      }),
    );

    final loaded = await repository.load();
    expect(
      loaded,
      ModelParams.defaults().copyWith(
        modelPath: '/models/x.gguf',
        contextSize: 1024,
        gpuLayers: 1,
        threads: 2,
        temperature: 0.5,
        topP: 0.9,
        topK: 10,
        maxTokens: 64,
      ),
    );
  });

  test('load falls back to defaults when validation fails', () async {
    await paramsFile.writeAsString(
      YamlEncoder.encode(<String, Object?>{
        'schemaVersion': 1,
        'params': <String, Object?>{
          'modelPath': '',
          'contextSize': 0,
          'gpuLayers': 0,
          'threads': 4,
          'temperature': 0.8,
          'topP': 0.95,
          'topK': 40,
          'maxTokens': 256,
        },
      }),
    );

    expect(await repository.load(), ModelParams.defaults());
  });

  test('save rejects invalid parameters without touching the file', () async {
    await repository.save(_params());
    final before = await paramsFile.readAsString();

    await expectLater(
      repository.save(_params().copyWith(contextSize: 0)),
      throwsA(isA<InvalidModelParamsException>()),
    );

    expect(await paramsFile.readAsString(), before);
  });

  test(
    'round-trips a path with spaces, a hash and Windows separators',
    () async {
      final modelPath = r'C:\models\my model #1.gguf';
      final params = ModelParams.defaults().copyWith(modelPath: modelPath);

      await repository.save(params);

      expect(await repository.load(), params);
    },
  );

  test('round-trips a model path containing a newline', () async {
    final params = ModelParams.defaults().copyWith(modelPath: 'a\nb.gguf');

    await repository.save(params);

    expect(await paramsFile.readAsString(), contains('"a\\nb.gguf"'));
    expect(await repository.load(), params);
  });

  test('preserves a temperature of 1.0 as a double', () async {
    final params = ModelParams.defaults().copyWith(temperature: 1.0);

    await repository.save(params);
    final loaded = await repository.load();

    expect(loaded.temperature, isA<double>());
    expect(loaded.temperature, 1.0);
  });

  test('accepts an empty model path', () async {
    final params = ModelParams.defaults().copyWith(modelPath: '');

    await repository.save(params);

    expect(await paramsFile.exists(), isTrue);
    expect((await repository.load()).modelPath, '');
  });
}
