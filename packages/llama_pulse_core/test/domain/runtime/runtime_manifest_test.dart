import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

RuntimeManifest _manifest({
  String tag = 'v0.8.0',
  RuntimeBackend backend = RuntimeBackend.cpu,
  RuntimePlatform platform = RuntimePlatform.linuxX64,
}) => RuntimeManifest(
  (b) => b
    ..tag = tag
    ..buildId = 'b11960'
    ..commit = '8642541b255bfb5dc39cd351a178be09013a55d6'
    ..backend = backend
    ..platform = platform
    ..assetName = 'llama-b11960-bin-ubuntu-x64.tar.gz'
    ..sha256 =
        '31cc3a6bc638ac6c48dc4b1b74888f1eaadf3d14227c1e5f67daf9a49541d97a'
    ..sizeBytes = 22686210
    ..installedAtEpochMs = 1700000000000
    ..llamaVersion = '0.8.0'
    ..buildNumber = 11960
    ..backendLibs = BuiltList<String>(<String>['libggml-cpu.so']).toBuilder()
    ..requires = 'No GPU driver; runs on the host CPU.'
    ..files = 12,
);

Map<String, Object?> _asMap(Object? value) {
  expect(value, isA<Map<String, Object?>>());
  return value as Map<String, Object?>;
}

void main() {
  group('RuntimeManifest', () {
    test('declares schema version 1', () {
      expect(RuntimeManifest.schemaVersion, 1);
    });

    test('serializes backend and platform by their stable ids', () {
      final serialized = _asMap(
        serializers.serializeWith(RuntimeManifest.serializer, _manifest()),
      );

      expect(serialized['backend'], 'cpu');
      expect(serialized['platform'], 'linux-x64');
      expect(serialized['tag'], 'v0.8.0');
      expect(serialized['build'], 'b11960');
      expect(serialized['backendLibs'], <String>['libggml-cpu.so']);
      expect(serialized['files'], 12);
    });

    test('round-trips every field', () {
      final manifest = _manifest(backend: RuntimeBackend.cuda13);

      final serialized = serializers.serializeWith(
        RuntimeManifest.serializer,
        manifest,
      );
      final decoded = serializers.deserializeWith(
        RuntimeManifest.serializer,
        serialized,
      );

      expect(decoded, manifest);
      final value = decoded as RuntimeManifest;
      expect(value.backend, RuntimeBackend.cuda13);
      expect(value.platform, RuntimePlatform.linuxX64);
      expect(value.llamaVersion, '0.8.0');
      expect(value.buildNumber, 11960);
      expect(value.requires, isNotNull);
    });

    test('round-trips absent nullable fields', () {
      final manifest = _manifest().rebuild(
        (b) => b
          ..llamaVersion = null
          ..buildNumber = null
          ..requires = null,
      );

      final serialized = serializers.serializeWith(
        RuntimeManifest.serializer,
        manifest,
      );
      final decoded = serializers.deserializeWith(
        RuntimeManifest.serializer,
        serialized,
      );

      expect(decoded, manifest);
      final value = decoded as RuntimeManifest;
      expect(value.llamaVersion, isNull);
      expect(value.buildNumber, isNull);
      expect(value.requires, isNull);
    });

    test('tolerates unknown keys when deserializing', () {
      final manifest = _manifest();
      final serialized = _asMap(
        serializers.serializeWith(RuntimeManifest.serializer, manifest),
      );

      final decoded = serializers.deserializeWith(
        RuntimeManifest.serializer,
        <String, Object?>{...serialized, 'futureField': 'ignored'},
      );

      expect(decoded, manifest);
    });
  });

  group('RuntimeIndex', () {
    test('empty starts with no selection and nothing installed', () {
      final index = RuntimeIndex.empty();

      expect(RuntimeIndex.schemaVersion, 1);
      expect(index.selectedTag, '');
      expect(index.selectedBackend, isNull);
      expect(index.hasSelection, isFalse);
      expect(index.selected, isNull);
      expect(index.installed, isEmpty);
    });

    test('round-trips install refs and the selection', () {
      final index = RuntimeIndex(
        (b) => b
          ..selectedTag = 'v0.8.0'
          ..selectedBackend = RuntimeBackend.cuda13
          ..installed = BuiltList<RuntimeInstallRef>(<RuntimeInstallRef>[
            RuntimeInstallRef(
              (ref) => ref
                ..tag = 'v0.8.0'
                ..backend = RuntimeBackend.cuda13
                ..platform = RuntimePlatform.linuxX64
                ..installedAtEpochMs = 1000
                ..sizeBytes = 2000,
            ),
            RuntimeInstallRef(
              (ref) => ref
                ..tag = 'v0.8.0'
                ..backend = RuntimeBackend.cpu
                ..platform = RuntimePlatform.linuxX64
                ..installedAtEpochMs = 3000
                ..sizeBytes = 4000,
            ),
          ]).toBuilder(),
      );

      final serialized = _asMap(
        serializers.serializeWith(RuntimeIndex.serializer, index),
      );
      expect(serialized['selectedBackend'], 'cuda13');
      final installed = serialized['installed'];
      expect(installed, isA<List<Object?>>());
      final installedList = installed as List<Object?>;
      expect(installedList, hasLength(2));

      final decoded = serializers.deserializeWith(
        RuntimeIndex.serializer,
        serialized,
      );

      expect(decoded, index);
      final value = decoded as RuntimeIndex;
      expect(value.selected?.backend, RuntimeBackend.cuda13);
      expect(value.installed.first.id, 'v0.8.0/cuda13');
    });

    test('selected is null when the selection is stale', () {
      final index = RuntimeIndex(
        (b) => b
          ..selectedTag = 'v0.8.0'
          ..selectedBackend = RuntimeBackend.cuda13
          ..installed = BuiltList<RuntimeInstallRef>().toBuilder(),
      );

      expect(index.hasSelection, isTrue);
      expect(index.selected, isNull);
    });
  });
}
