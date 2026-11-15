import 'runtime_backend.dart';
import 'runtime_platform.dart';

/// One pinned, downloadable archive of a llama.cpp release.
///
/// Assets are identified by their exact upstream name, size and SHA-256
/// digest. Upstream release assets are mutable — a name can be re-uploaded
/// with different content — so the digest recorded here is the only thing the
/// downloader trusts, and it is never looked up from the API at install time.
class RuntimeAsset {
  const RuntimeAsset({
    required this.tag,
    required this.backend,
    required this.platform,
    required this.assetName,
    required this.sha256,
    required this.sizeBytes,
    this.assetTag,
    this.additionalBackends = const <RuntimeBackend>[],
    this.cudartAsset,
  });

  /// The release tag that identifies this install, for example `v0.8.0`.
  ///
  /// This is the install identity: manifests, attestation, the CLI `--tag`
  /// option and the `<config>/runtime/<tag>/<backend>` layout all use it. It is
  /// not necessarily the GitHub release that holds the archive; see [assetTag].
  final String tag;

  /// The GitHub release tag that physically holds the archive, if it differs
  /// from [tag].
  ///
  /// Upstream can publish a tag that only carries `nightly-tag.txt` and put the
  /// binaries on the nightly build it names. A null value means the archive
  /// lives on [tag] itself.
  final String? assetTag;

  /// The compute backend this archive is built for.
  final RuntimeBackend backend;

  /// The host platform this archive runs on.
  final RuntimePlatform platform;

  /// The exact upstream asset file name.
  final String assetName;

  /// Lower-case hex SHA-256 of the archive, as published by upstream.
  final String sha256;

  /// Exact archive size in bytes, as published by upstream.
  final int sizeBytes;

  /// Extra backends this same archive also carries libraries for.
  ///
  /// The macOS archive is the only one: it is built for Metal and includes the
  /// CPU backend, so there is no separate macOS CPU download.
  final List<RuntimeBackend> additionalBackends;

  /// The companion CUDA runtime archive a CUDA build needs, if any.
  ///
  /// CUDA is the one backend whose runtime libraries ship separately, so a
  /// CUDA install is two verified downloads.
  final RuntimeAsset? cudartAsset;

  /// The GitHub release download URL for this archive.
  ///
  /// Built from [assetTag] when it is set, so the URL points at the release
  /// that actually carries the archive rather than the install tag.
  String get url =>
      'https://github.com/ggml-org/llama.cpp/releases/download/'
      '${assetTag ?? tag}/$assetName';

  /// Rough unpacked size, used to check free disk space before downloading.
  ///
  /// llama.cpp archives are compressed; the estimate assumes the unpacked tree
  /// is 2.5x the archive, which is generous for binaries and safe to
  /// over-reserve.
  int get unpackedBytes => (sizeBytes * 2.5).round();

  /// The driver floor a host must meet before this archive can run.
  String get requirements => backend.requires;

  /// Every backend this archive carries libraries for.
  List<RuntimeBackend> get backends => <RuntimeBackend>[
    backend,
    ...additionalBackends,
  ];

  /// Whether this archive carries [backend]'s libraries.
  bool provides(RuntimeBackend backend) => backends.contains(backend);

  /// Whether the archive unpacks [name] as one of its backend libraries.
  ///
  /// Used to check an extracted tree before the runtime is registered.
  bool containsBackendLib(String name) {
    for (final backend in backends) {
      if (backend.backendLibs(platform).contains(name)) {
        return true;
      }
    }
    return false;
  }
}
