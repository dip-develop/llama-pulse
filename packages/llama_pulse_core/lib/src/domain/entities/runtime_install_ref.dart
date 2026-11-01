import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import '../runtime/runtime_backend.dart';
import '../runtime/runtime_platform.dart';

part 'runtime_install_ref.g.dart';

/// A compact record of one installed runtime in `runtime/index.yaml`.
///
/// The full details live in the install directory's `runtime.yaml`; the index
/// only carries what a listing needs.
abstract class RuntimeInstallRef
    implements Built<RuntimeInstallRef, RuntimeInstallRefBuilder> {
  /// The release tag, for example `v0.8.0`.
  String get tag;

  /// The installed compute backend.
  RuntimeBackend get backend;

  /// The platform the installed archive targets.
  RuntimePlatform get platform;

  /// When the runtime was committed, in milliseconds since the epoch.
  int get installedAtEpochMs;

  /// Total installed size in bytes.
  int get sizeBytes;

  /// `tag/backend`, the identity used by the runtime store.
  String get id => '$tag/${backend.id}';

  factory RuntimeInstallRef([
    void Function(RuntimeInstallRefBuilder)? updates,
  ]) = _$RuntimeInstallRef;

  RuntimeInstallRef._();

  static Serializer<RuntimeInstallRef> get serializer =>
      _$runtimeInstallRefSerializer;
}
