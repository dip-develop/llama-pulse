import 'dart:io';

import '../entities/runtime_index.dart';
import '../entities/runtime_install_ref.dart';
import '../entities/runtime_manifest.dart';
import '../runtime/runtime_backend.dart';

/// Manages the runtimes installed under `<config>/runtime/`.
///
/// Layout:
///
/// ```
/// <config>/runtime/index.yaml
/// <config>/runtime/<tag>/<backend>/runtime.yaml
/// <config>/runtime/<tag>/<backend>/llama-server
/// ```
///
/// Implementations never throw from [list], [index] or [manifest]; a missing
/// or corrupt document degrades to an empty result. Mutations throw
/// [StateError] when their precondition is not met.
abstract interface class RuntimeStore {
  /// Every committed runtime, in index order.
  Future<List<RuntimeInstallRef>> list();

  /// The manifest at `runtime/<tag>/<backend>/runtime.yaml`, or null when it is
  /// missing or malformed.
  Future<RuntimeManifest?> manifest(String tag, RuntimeBackend backend);

  /// The parsed index, or an empty index when `index.yaml` is missing or
  /// malformed.
  Future<RuntimeIndex> index();

  /// Marks `runtime/<tag>/<backend>` as the default runtime.
  Future<void> select(String tag, RuntimeBackend backend);

  /// Deletes `runtime/<tag>/<backend>` and drops it from the index.
  Future<void> remove(String tag, RuntimeBackend backend);

  /// Verifies [stagingDir] and moves it to `runtime/<tag>/<backend>`.
  ///
  /// Throws [StateError] when the staging directory does not contain the
  /// expected server binary, when [manifest] does not describe [backend], or
  /// when the install already exists and [force] is false.
  Future<void> commit(
    RuntimeBackend backend,
    RuntimeManifest manifest,
    Directory stagingDir, {
    bool force = false,
  });

  /// Deletes abandoned staging directories older than [olderThan].
  Future<void> cleanupOrphans({Duration olderThan = const Duration(days: 1)});

  /// Absolute install directory for [tag] and [backend].
  String installDirectory(String tag, RuntimeBackend backend);
}
