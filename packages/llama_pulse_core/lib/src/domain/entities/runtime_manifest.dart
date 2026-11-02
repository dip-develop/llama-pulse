import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import '../runtime/runtime_backend.dart';
import '../runtime/runtime_platform.dart';

part 'runtime_manifest.g.dart';

/// What was installed into one `runtime/<tag>/<backend>/` directory.
///
/// The manifest is written as `runtime.yaml` next to the extracted binaries and
/// is the source of truth the loader and the CLI use to identify an install.
abstract class RuntimeManifest
    implements Built<RuntimeManifest, RuntimeManifestBuilder> {
  /// Version of the `runtime.yaml` schema.
  static const int schemaVersion = 1;

  /// The upstream release tag the archive came from.
  String get tag;

  /// The upstream build number, for example `b11960`.
  ///
  /// The YAML key stays `build`; the Dart name cannot be `build` because
  /// `Built` already declares `build()`.
  @BuiltValueField(wireName: 'build')
  String get buildId;

  /// The upstream commit the archive was built from.
  String get commit;

  /// The compute backend the archive is built for.
  RuntimeBackend get backend;

  /// The platform the archive targets.
  RuntimePlatform get platform;

  /// The exact upstream asset name that was downloaded.
  String get assetName;

  /// Lower-case hex SHA-256 of the downloaded archive.
  String get sha256;

  /// Size of the downloaded archive in bytes.
  int get sizeBytes;

  /// When the runtime was committed, in milliseconds since the epoch.
  int get installedAtEpochMs;

  /// The llama.cpp version the installed binary reports, when known.
  String? get llamaVersion;

  /// The upstream build number as an integer, when known.
  int? get buildNumber;

  /// Shared libraries the loader must open before the main `llama` library.
  BuiltList<String> get backendLibs;

  /// Human-readable driver requirement recorded at install time.
  String? get requires;

  /// Number of files extracted into the install directory.
  int get files;

  factory RuntimeManifest([void Function(RuntimeManifestBuilder)? updates]) =
      _$RuntimeManifest;

  RuntimeManifest._();

  static Serializer<RuntimeManifest> get serializer =>
      _$runtimeManifestSerializer;
}
