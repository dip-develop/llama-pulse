import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<Directory> createTempDirectory() async {
  final directory = await Directory.systemTemp.createTemp('llama_pulse_yaml_');
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return directory;
}

void main() {
  group('YamlFileConfigStore', () {
    test('round-trips a nested document', () async {
      final directory = await createTempDirectory();
      final store = YamlFileConfigStore(directory: directory.path);
      final document = <String, Object?>{
        'schemaVersion': 1,
        'params': <String, Object?>{
          'modelPath': '/models/a.gguf',
          'flags': <Object?>[true, false, null],
        },
      };

      await store.write('params', document);
      expect(await store.read('params'), document);
    });

    test('writes schemaVersion first with one trailing newline', () async {
      final directory = await createTempDirectory();
      final store = YamlFileConfigStore(directory: directory.path);

      await store.write('params', <String, Object?>{
        'schemaVersion': 1,
        'params': <String, Object?>{'modelPath': ''},
      });

      final content = await File(p.join(directory.path, 'params.yaml'))
          .readAsString();
      expect(content, startsWith('schemaVersion: 1\n'));
      expect(content, endsWith('\n'));
      expect(content, isNot(endsWith('\n\n')));
      expect(content, isNot(contains('---')));
    });

    test('leaves no temporary file behind', () async {
      final directory = await createTempDirectory();
      final store = YamlFileConfigStore(directory: directory.path);

      await store.write('params', <String, Object?>{'schemaVersion': 1});

      final names = await directory
          .list()
          .map((entity) => p.basename(entity.path))
          .toList();
      expect(names, ['params.yaml']);
    });

    test(
      'concurrent writes leave a valid document and no temp files',
      () async {
        final directory = await createTempDirectory();
        final store = YamlFileConfigStore(directory: directory.path);

        await Future.wait<void>([
          store.write('params', <String, Object?>{
            'schemaVersion': 1,
            'writer': 'a',
          }),
          store.write('params', <String, Object?>{
            'schemaVersion': 1,
            'writer': 'b',
          }),
        ]);

        final document = await store.read('params');
        expect(document?['schemaVersion'], 1);
        expect(document?['writer'], anyOf('a', 'b'));

        final names = await directory
            .list()
            .map((entity) => p.basename(entity.path))
            .toList();
        expect(names.where((name) => name.contains('.tmp')), isEmpty);
        expect(names, ['params.yaml']);
      },
    );

    test('delete removes the document', () async {
      final directory = await createTempDirectory();
      final store = YamlFileConfigStore(directory: directory.path);
      await store.write('params', <String, Object?>{'schemaVersion': 1});

      await store.delete('params');

      expect(await store.read('params'), isNull);
    });

    test('delete is a no-op for an absent document', () async {
      final directory = await createTempDirectory();
      final store = YamlFileConfigStore(directory: directory.path);

      await store.delete('params');

      expect(await store.read('params'), isNull);
    });

    test('returns null for a missing document', () async {
      final directory = await createTempDirectory();
      final store = YamlFileConfigStore(directory: directory.path);

      expect(await store.read('params'), isNull);
    });

    test('rejects an invalid document name', () async {
      final directory = await createTempDirectory();
      final store = YamlFileConfigStore(directory: directory.path);

      await expectLater(store.read('Params-File'), throwsArgumentError);
      await expectLater(
        store.write('params/evil', <String, Object?>{}),
        throwsArgumentError,
      );
    });

    test('accepts a hyphenated document name', () async {
      final directory = await createTempDirectory();
      final store = YamlFileConfigStore(directory: directory.path);

      await store.write('server-state', <String, Object?>{'schemaVersion': 1});

      final file = File(p.join(directory.path, 'server-state.yaml'));
      expect(await file.exists(), isTrue);
      expect(await store.read('server-state'), {'schemaVersion': 1});
    });

    test('throws FormatException for unparsable YAML', () async {
      final directory = await createTempDirectory();
      final file = File(p.join(directory.path, 'params.yaml'));
      await file.writeAsString('not: [valid');
      final store = YamlFileConfigStore(directory: directory.path);

      await expectLater(store.read('params'), throwsFormatException);
    });
  });

  group('InMemoryConfigStore', () {
    test('deep-copies on write and read', () async {
      final store = InMemoryConfigStore();
      final source = <String, Object?>{
        'nested': <String, Object?>{
          'values': <Object?>[1, 2],
        },
      };

      await store.write('doc', source);
      (source['nested'] as Map<String, Object?>)['values'] = <Object?>[9];

      final first = await store.read('doc');
      final firstNested = first?['nested'] as Map<String, Object?>;
      expect(firstNested['values'], <Object?>[1, 2]);

      (firstNested['values'] as List<Object?>).add(3);

      final second = await store.read('doc');
      final secondNested = second?['nested'] as Map<String, Object?>;
      expect(secondNested['values'], <Object?>[1, 2]);
    });

    test('delete removes the document', () async {
      final store = InMemoryConfigStore();
      await store.write('doc', <String, Object?>{'x': 1});

      await store.delete('doc');

      expect(await store.read('doc'), isNull);
    });
  });
}
