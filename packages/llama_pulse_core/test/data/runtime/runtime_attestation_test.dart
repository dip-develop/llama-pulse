import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

RuntimeManifest _manifest({
  String tag = 'v0.8.0',
  String buildId = 'b11960',
  String commit = '8642541b255bfb5dc39cd351a178be09013a55d6',
  RuntimeBackend backend = RuntimeBackend.cpu,
  RuntimePlatform platform = RuntimePlatform.linuxX64,
  String assetName = 'llama-b11960-bin-ubuntu-x64.tar.gz',
  String sha256 =
      '31cc3a6bc638ac6c48dc4b1b74888f1eaadf3d14227c1e5f67daf9a49541d97a',
  int sizeBytes = 22686210,
}) => RuntimeManifest(
  (b) => b
    ..tag = tag
    ..buildId = buildId
    ..commit = commit
    ..backend = backend
    ..platform = platform
    ..assetName = assetName
    ..sha256 = sha256
    ..sizeBytes = sizeBytes
    ..installedAtEpochMs = 1000
    ..llamaVersion = '0.8.0-dev'
    ..buildNumber = 11960
    ..backendLibs = BuiltList<String>(backend.backendLibs(platform)).toBuilder()
    ..files = 42,
);

void main() {
  group('RuntimeAttestation.verify', () {
    test('accepts the pinned manifest', () {
      final attestation = RuntimeAttestation.verify(_manifest());

      expect(attestation.isAttested, isTrue, reason: attestation.reason);
      expect(attestation.tag, 'v0.8.0');
      expect(attestation.buildId, 'b11960');
      expect(attestation.backend, RuntimeBackend.cpu);
    });

    test('accepts an abbreviated commit while the asset matches', () {
      final attestation = RuntimeAttestation.verify(
        _manifest(commit: '8642541'),
      );

      expect(attestation.isAttested, isTrue, reason: attestation.reason);
    });

    test('rejects another tag', () {
      expect(
        RuntimeAttestation.verify(_manifest(tag: 'v0.7.0')).code,
        RuntimeAttestationCode.manifestMismatch,
      );
    });

    test('rejects another build', () {
      expect(
        RuntimeAttestation.verify(_manifest(buildId: 'b11959')).code,
        RuntimeAttestationCode.manifestMismatch,
      );
    });

    test('rejects a foreign commit', () {
      final attestation = RuntimeAttestation.verify(
        _manifest(commit: '0123456789abcdef0123456789abcdef01234567'),
      );

      expect(attestation.code, RuntimeAttestationCode.manifestMismatch);
      expect(attestation.reason, contains('commit'));
    });

    test('rejects an abbreviated commit shorter than seven characters', () {
      expect(
        RuntimeAttestation.verify(_manifest(commit: '864254')).code,
        RuntimeAttestationCode.manifestMismatch,
      );
    });

    test('rejects an archive with a different digest', () {
      final attestation = RuntimeAttestation.verify(
        _manifest(sha256: 'f' * 64),
      );

      expect(attestation.code, RuntimeAttestationCode.manifestMismatch);
      expect(attestation.reason, contains('SHA-256'));
    });

    test('rejects an archive with a different size', () {
      expect(
        RuntimeAttestation.verify(_manifest(sizeBytes: 1)).code,
        RuntimeAttestationCode.manifestMismatch,
      );
    });

    test('rejects a backend the release does not ship', () {
      expect(
        RuntimeAttestation.verify(
          _manifest(
            backend: RuntimeBackend.metal,
            platform: RuntimePlatform.windowsX64,
            assetName: 'llama-b11960-bin-win-cpu-x64.zip',
          ),
        ).code,
        RuntimeAttestationCode.manifestMismatch,
      );
    });
  });

  group('RuntimeAttestation.read', () {
    late Directory temp;
    late String libraryPath;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('llama_pulse_attest_');
      libraryPath = p.join(temp.path, 'libllama.so');
      File(libraryPath).writeAsStringSync('');
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

    test('missing manifest rejects', () {
      final attestation = RuntimeAttestation.read(libraryPath);

      expect(attestation.code, RuntimeAttestationCode.missingManifest);
      expect(attestation.reason, contains('runtime.yaml'));
    });

    test('a matching manifest attests', () {
      writeManifest(_manifest());

      expect(RuntimeAttestation.read(libraryPath).isAttested, isTrue);
    });

    test('a corrupt manifest rejects instead of throwing', () {
      File(p.join(temp.path, 'runtime.yaml'))
          .writeAsStringSync('schemaVersion: 1\n:: not yaml');

      expect(
        RuntimeAttestation.read(libraryPath).code,
        RuntimeAttestationCode.missingManifest,
      );
    });

    test('a manifest for an archive outside the release rejects', () {
      writeManifest(_manifest(assetName: 'llama-b99999-bin-ubuntu-x64.tar.gz'));

      final attestation = RuntimeAttestation.read(libraryPath);

      expect(attestation.code, RuntimeAttestationCode.manifestMismatch);
      expect(attestation.reason, contains('archive'));
    });
  });
}
