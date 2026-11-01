import 'dart:io';

import 'package:built_value/serializer.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/runtime_manifest.dart';
import '../../domain/runtime/runtime_backend.dart';
import '../../domain/runtime/runtime_release.dart';
import '../config/yaml_decoder.dart';
import '../serialization/serializers.dart' as core;

/// Why the native version gate accepted or rejected a library.
enum RuntimeAttestationCode {
  /// The manifest beside the library matches the pinned release exactly.
  attested,

  /// There is no readable `runtime.yaml` in the library directory.
  missingManifest,

  /// `runtime.yaml` exists but does not describe the pinned release.
  manifestMismatch,
}

/// Proof that a library reporting `0.8.0-dev` is the pinned prebuilt build.
///
/// Official llama.cpp prebuilt archives are built with
/// `-DLLAMA_BUILD_IS_DEV=ON`, so `llama_version()` returns `0.8.0-dev` even
/// though the source is exactly the pinned `v0.8.0` commit. The gate accepts
/// that string only when the installed runtime's manifest names the pinned
/// tag, build, commit and archive digest; a local `-DLLAMA_BUILD_IS_DEV=OFF`
/// build keeps reporting `0.8.0` and passes the exact check.
final class RuntimeAttestation {
  const RuntimeAttestation._({
    required this.code,
    required this.reason,
    this.tag,
    this.buildId,
    this.backend,
  });

  /// The verdict.
  final RuntimeAttestationCode code;

  /// Human-readable evidence for [code].
  final String reason;

  /// The manifest's release tag, when one was read.
  final String? tag;

  /// The manifest's build id, when one was read.
  final String? buildId;

  /// The manifest's backend, when one was read.
  final RuntimeBackend? backend;

  /// Whether the manifest matches the pin.
  bool get isAttested => code == RuntimeAttestationCode.attested;

  /// Reads `runtime.yaml` beside [libraryPath] and checks it against [release].
  ///
  /// Any parse or IO problem degrades to a rejection: the gate never accepts a
  /// library on an unreadable manifest.
  static RuntimeAttestation read(
    String libraryPath, {
    RuntimeRelease release = RuntimeRelease.v080,
    Serializers? serializers,
  }) {
    try {
      final file = File(p.join(p.dirname(libraryPath), 'runtime.yaml'));
      if (!file.existsSync()) {
        return RuntimeAttestation._(
          code: RuntimeAttestationCode.missingManifest,
          reason: 'no runtime.yaml beside $libraryPath',
        );
      }
      final document = YamlDecoder.decode(file.readAsStringSync());
      if (document['schemaVersion'] != RuntimeManifest.schemaVersion) {
        return const RuntimeAttestation._(
          code: RuntimeAttestationCode.missingManifest,
          reason: 'runtime.yaml has an unknown schema version',
        );
      }
      final body = Map<String, Object?>.from(document)..remove('schemaVersion');
      final manifest = (serializers ?? core.serializers).deserializeWith(
        RuntimeManifest.serializer,
        body,
      );
      if (manifest == null) {
        return const RuntimeAttestation._(
          code: RuntimeAttestationCode.missingManifest,
          reason: 'runtime.yaml did not parse into a manifest',
        );
      }
      return verify(manifest, release: release);
    } on Object catch (error) {
      return RuntimeAttestation._(
        code: RuntimeAttestationCode.missingManifest,
        reason: 'runtime.yaml could not be read: $error',
      );
    }
  }

  /// Checks one parsed [manifest] against [release].
  static RuntimeAttestation verify(
    RuntimeManifest manifest, {
    RuntimeRelease release = RuntimeRelease.v080,
  }) {
    RuntimeAttestation reject(String reason) => RuntimeAttestation._(
      code: RuntimeAttestationCode.manifestMismatch,
      reason: reason,
      tag: manifest.tag,
      buildId: manifest.buildId,
      backend: manifest.backend,
    );

    if (manifest.tag != release.tag) {
      return reject(
        'runtime manifest tag is "${manifest.tag}", expected "${release.tag}"',
      );
    }
    if (manifest.buildId != release.build) {
      return reject(
        'runtime manifest build is "${manifest.buildId}", expected '
        '"${release.build}"',
      );
    }
    final commit = manifest.commit.trim().toLowerCase();
    final pinnedCommit = release.commit.toLowerCase();
    if (commit.length < 7 || !pinnedCommit.startsWith(commit)) {
      return reject(
        'runtime manifest commit is "${manifest.commit}", expected '
        '"${release.commit}"',
      );
    }
    final asset = release.forBackend(manifest.backend, manifest.platform);
    if (asset == null) {
      return reject(
        'release ${release.tag} has no ${manifest.backend.id} archive for '
        '${manifest.platform.id}',
      );
    }
    if (manifest.assetName != asset.assetName) {
      return reject(
        'runtime manifest archive is "${manifest.assetName}", expected '
        '"${asset.assetName}"',
      );
    }
    if (manifest.sha256.trim().toLowerCase() != asset.sha256.toLowerCase()) {
      return reject(
        'runtime manifest SHA-256 does not match the pinned '
        '${asset.assetName}',
      );
    }
    if (manifest.sizeBytes != asset.sizeBytes) {
      return reject(
        'runtime manifest archive size is ${manifest.sizeBytes} bytes, '
        'expected ${asset.sizeBytes}',
      );
    }
    return RuntimeAttestation._(
      code: RuntimeAttestationCode.attested,
      reason: 'runtime manifest matches ${release.tag} ${release.build}',
      tag: manifest.tag,
      buildId: manifest.buildId,
      backend: manifest.backend,
    );
  }
}
