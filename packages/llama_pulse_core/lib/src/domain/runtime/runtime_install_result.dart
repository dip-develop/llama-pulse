import 'dart:io';

import 'runtime_asset.dart';
import 'runtime_backend.dart';
import 'runtime_platform.dart';

/// Everything the store needs after a runtime archive has been downloaded,
/// verified, extracted and probed.
///
/// The downloader does not write `runtime.yaml`: it hands back the manifest
/// fields, the extracted payload and whatever `llama-server --version`
/// reported, and the store commits the staging directory in one rename.
final class RuntimeInstallResult {
  /// Creates an install result.
  RuntimeInstallResult({
    required this.tag,
    required this.backend,
    required this.platform,
    required this.assetName,
    required this.sha256,
    required this.sizeBytes,
    required this.payloadDir,
    required this.files,
    List<RuntimeAsset> assets = const <RuntimeAsset>[],
    this.buildId,
    this.commit,
    this.serverVersion,
    this.buildNumber,
  }) : assets = List<RuntimeAsset>.unmodifiable(assets);

  /// The upstream release tag the archives came from.
  final String tag;

  /// The backend the primary archive was built for.
  final RuntimeBackend backend;

  /// The platform the primary archive targets.
  final RuntimePlatform platform;

  /// Exact upstream name of the primary archive.
  final String assetName;

  /// Lower-case hex SHA-256 of the primary archive.
  final String sha256;

  /// Size of the primary archive in bytes.
  final int sizeBytes;

  /// Directory holding the extracted tree, with the archive's top-level
  /// directory stripped.
  final Directory payloadDir;

  /// Number of regular files extracted from every archive.
  final int files;

  /// Every archive that was downloaded, primary first and the CUDA runtime
  /// second when there was one.
  final List<RuntimeAsset> assets;

  /// Upstream build id, for example `b11960`.
  ///
  /// Taken from `llama-server --version` when probing worked, and otherwise
  /// read from the archive name, which carries the build number upstream.
  /// Null only when neither source names a build.
  final String? buildId;

  /// Upstream commit reported by `llama-server --version`, when it reported
  /// one and probing succeeded.
  final String? commit;

  /// The version string the extracted binary reported, for example `0.8.0`.
  final String? serverVersion;

  /// The numeric build the extracted binary reported, for example `11960`.
  final int? buildNumber;

  /// The primary archive.
  RuntimeAsset get asset => assets.first;
}
