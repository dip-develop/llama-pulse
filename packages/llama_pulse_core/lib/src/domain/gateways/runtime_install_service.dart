import '../runtime/runtime_asset.dart';
import '../runtime/runtime_fetcher.dart';
import '../runtime/runtime_release.dart';

/// Installs one pinned runtime archive.
///
/// The GUI depends on this contract so its tests can drive an install without
/// touching the network or the file system. `RuntimeInstaller` in the data
/// layer is the only production implementation.
abstract interface class RuntimeInstallService {
  /// The release whose assets this service installs.
  RuntimeRelease get release;

  /// Downloads, verifies, extracts and commits [asset].
  ///
  /// [onProgress] receives throttled progress reports. [cancel] stops the
  /// transfer cooperatively. When the runtime is already installed and
  /// [force] is false the service throws instead of replacing it.
  Future<void> install({
    required RuntimeAsset asset,
    required void Function(RuntimeProgress progress) onProgress,
    RuntimeCancelToken? cancel,
    bool force = false,
  });
}
