import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:llama_pulse_core/src/data/inference/native/llama_library.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../support/native/fake_llama_builder.dart';

RuntimeManifest _pinnedManifest() => RuntimeManifest(
  (b) => b
    ..tag = 'v0.8.0'
    ..buildId = 'b11960'
    ..commit = '8642541b255bfb5dc39cd351a178be09013a55d6'
    ..backend = RuntimeBackend.cpu
    ..platform = RuntimePlatform.linuxX64
    ..assetName = 'llama-b11960-bin-ubuntu-x64.tar.gz'
    ..sha256 =
        '31cc3a6bc638ac6c48dc4b1b74888f1eaadf3d14227c1e5f67daf9a49541d97a'
    ..sizeBytes = 22686210
    ..installedAtEpochMs = 1000
    ..llamaVersion = '0.8.0-dev'
    ..buildNumber = 11960
    ..backendLibs = BuiltList<String>(<String>['libggml-cpu.so']).toBuilder()
    ..files = 42,
);

void main() {
  late Directory temp;
  late String libraryPath;
  late FakeLlama fake;
  String? skipReason;

  setUpAll(() async {
    if (!await FakeLlamaBuilder.isAvailable) {
      skipReason = 'clang is not installed; the native shim needs a compiler';
    }
  });

  setUp(() async {
    if (skipReason != null) {
      return;
    }
    temp = Directory.systemTemp.createTempSync('llama_pulse_gate_');
    final shim = await FakeLlamaBuilder.build();
    libraryPath = (await File(shim).copy(p.join(temp.path, p.basename(shim))))
        .path;
    fake = FakeLlama(libraryPath);
  });

  tearDown(() {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  void writeManifest(RuntimeManifest manifest) {
    final body =
        serializers.serializeWith(RuntimeManifest.serializer, manifest)!
            as Map<String, Object?>;
    File(p.join(temp.path, 'runtime.yaml')).writeAsStringSync(
      YamlEncoder.encode(<String, Object?>{
        'schemaVersion': RuntimeManifest.schemaVersion,
        ...body,
      }),
    );
  }

  test('accepts 0.8.0-dev only with a manifest that matches the pin', () async {
    if (skipReason != null) {
      return;
    }
    fake.setVersion('0.8.0-dev');
    writeManifest(_pinnedManifest());

    final library = await LlamaLibrary.open(libraryPath);

    expect(library.isUsable, isTrue, reason: '${library.failure}');
    expect(library.version, '0.8.0-dev');
  });

  test('rejects 0.8.0-dev without a manifest', () async {
    if (skipReason != null) {
      return;
    }
    fake.setVersion('0.8.0-dev');

    final library = await LlamaLibrary.open(libraryPath);

    expect(library.failure?.code, InferenceFailureCode.libraryVersionMismatch);
    expect(library.failure?.details, contains('no runtime.yaml'));
  });

  test('rejects 0.8.0-dev with a manifest for another build', () async {
    if (skipReason != null) {
      return;
    }
    fake.setVersion('0.8.0-dev');
    writeManifest(_pinnedManifest().rebuild((b) => b..buildId = 'b11959'));

    final library = await LlamaLibrary.open(libraryPath);

    expect(library.failure?.code, InferenceFailureCode.libraryVersionMismatch);
    expect(library.failure?.details, contains('b11959'));
  });

  test('accepts a local 0.8.0 build without a manifest', () async {
    if (skipReason != null) {
      return;
    }
    fake.setVersion('0.8.0');

    final library = await LlamaLibrary.open(libraryPath);

    expect(library.isUsable, isTrue, reason: '${library.failure}');
  });

  test('still rejects a foreign dev build', () async {
    if (skipReason != null) {
      return;
    }
    fake.setVersion('0.7.0-dev');
    writeManifest(_pinnedManifest());

    final library = await LlamaLibrary.open(libraryPath);

    expect(library.failure?.code, InferenceFailureCode.libraryVersionMismatch);
    expect(library.failure?.message, contains('0.7.0-dev'));
  });
}
