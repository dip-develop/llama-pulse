import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/runtime_manifest.dart';
import '../../domain/gateways/process_executor.dart';
import '../../domain/gateways/runtime_store.dart';
import '../../domain/runtime/runtime_asset.dart';
import '../../domain/runtime/runtime_failure.dart';
import '../../domain/runtime/runtime_fetcher.dart';
import '../../domain/runtime/runtime_install_result.dart';
import '../../domain/runtime/runtime_release.dart';
import '../config/app_paths.dart';
import 'archive_extractor.dart';
import 'runtime_downloader.dart';

/// Installs one pinned runtime: download, verify, extract, manifest, commit.
///
/// The downloader and the store stay separate concerns; this class is the only
/// place that knows the staging directory layout and the manifest fields an
/// install needs. A failed or cancelled install removes its staging tree and
/// never touches an existing runtime.
final class RuntimeInstaller {
  /// Creates an installer.
  ///
  /// [executor] arms the optional `llama-server --version` probe; leave it
  /// null in tests that must not spawn a process. [clock] returns milliseconds
  /// since the epoch and is injectable for deterministic manifests.
  factory RuntimeInstaller({
    required RuntimeStore store,
    required RuntimeFetcher fetcher,
    required AppPaths paths,
    RuntimeRelease release = RuntimeRelease.v080,
    ArchiveExtractor? extractor,
    ProcessExecutor? executor,
    int Function()? clock,
  }) => RuntimeInstaller._(
    store,
    RuntimeDownloader(
      fetcher: fetcher,
      extractor: extractor ?? const ArchiveExtractor(),
      executor: executor,
    ),
    paths.runtimeDirectory,
    release,
    clock ?? _nowEpochMs,
  );

  RuntimeInstaller._(
    this._store,
    this._downloader,
    this._runtimeRoot,
    this._release,
    this._clock,
  );

  static int _stagingCounter = 0;

  final RuntimeStore _store;
  final RuntimeDownloader _downloader;
  final String _runtimeRoot;
  final RuntimeRelease _release;
  final int Function() _clock;

  /// The release this installer knows how to fetch.
  RuntimeRelease get release => _release;

  /// Installs [asset] into `<runtime>/<tag>/<backend>` and returns the payload.
  ///
  /// [onProgress] receives throttled download progress. [acceptCudart] is not
  /// consulted here: the caller asked for [asset], and an asset that carries a
  /// CUDA runtime archive always downloads it so the install is complete.
  ///
  /// Throws [RuntimeException] for download, verification and extraction
  /// failures and [StateError] when the runtime is already installed and
  /// [force] is false.
  Future<RuntimeInstallResult> install({
    required RuntimeAsset asset,
    required void Function(RuntimeProgress) onProgress,
    RuntimeCancelToken? cancel,
    bool force = false,
  }) async {
    final existing = await _store.manifest(asset.tag, asset.backend);
    if (existing != null && !force) {
      throw StateError(
        'runtime ${asset.tag}/${asset.backend.id} is already installed; '
        'pass --force to replace it',
      );
    }

    final staging = Directory(
      p.join(
        _runtimeRoot,
        '.tmp-${asset.tag}-${asset.backend.id}-$pid-${_stagingCounter++}',
      ),
    );
    var committed = false;
    try {
      await staging.create(recursive: true);
      final result = await _downloader.download(
        asset: asset,
        targetParent: staging,
        onProgress: onProgress,
        cancel: cancel,
      );
      final manifest = _manifestFor(asset, result);
      await _store.commit(
        asset.backend,
        manifest,
        result.payloadDir,
        force: force,
      );
      committed = true;
      // The payload moved into place; only the now-empty staging shell is left.
      await _deleteQuietly(staging);
      return result.withPayloadDirectory(
        Directory(_store.installDirectory(asset.tag, asset.backend)),
      );
    } on Object {
      final cancelled = cancel?.isCancelled ?? false;
      if (!committed) {
        await _deleteQuietly(staging);
      }
      if (cancelled) {
        throw const RuntimeException(
          RuntimeFailureCode.cancelled,
          'the runtime install was cancelled',
        );
      }
      rethrow;
    }
  }

  RuntimeManifest _manifestFor(
    RuntimeAsset asset,
    RuntimeInstallResult result,
  ) => RuntimeManifest(
    (b) => b
      ..tag = asset.tag
      ..buildId = result.buildId ?? _release.build
      ..commit = result.commit ?? _release.commit
      ..backend = asset.backend
      ..platform = asset.platform
      ..assetName = asset.assetName
      ..sha256 = asset.sha256
      ..sizeBytes = asset.sizeBytes
      ..installedAtEpochMs = _clock()
      ..llamaVersion = result.serverVersion
      ..buildNumber = result.buildNumber
      ..backendLibs = BuiltList<String>(_backendLibs(asset, result.payloadDir))
          .toBuilder()
      ..requires = asset.requirements
      ..files = result.files,
  );

  /// Backend plugin files the payload actually contains.
  ///
  /// Only existing regular files are recorded, so the store's staging check
  /// never fails on an upstream naming change it cannot know about.
  List<String> _backendLibs(RuntimeAsset asset, Directory payload) {
    final names = <String>[];
    try {
      for (final entity in payload.listSync(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final name = p.basename(entity.path);
        if (asset.containsBackendLib(name)) {
          names.add(name);
        }
      }
    } on FileSystemException {
      // A missing payload is caught by the store's own staging check.
    }
    names.sort();
    return names;
  }

  static Future<void> _deleteQuietly(Directory directory) async {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException {
      // A leftover staging tree is removed by cleanupOrphans eventually.
    }
  }

  static int _nowEpochMs() => DateTime.now().millisecondsSinceEpoch;
}
