import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../domain/gateways/process_executor.dart';
import '../../domain/runtime/runtime_asset.dart';
import '../../domain/runtime/runtime_failure.dart';
import '../../domain/runtime/runtime_fetcher.dart';
import '../../domain/runtime/runtime_install_result.dart';
import '../../domain/runtime/runtime_platform.dart';
import '../server/server_version_parser.dart';
import 'archive_extractor.dart';

/// Orchestrates one runtime install: download, verify, extract, probe.
///
/// The downloader owns a staging directory supplied by the caller. It never
/// writes `runtime.yaml` and never renames the directory: the store commits
/// the result once it has checked the payload, so a failed install cannot
/// leave a half-written runtime behind.
final class RuntimeDownloader {
  /// Creates a downloader.
  ///
  /// [fetcher] is the only network dependency. [executor] arms the optional
  /// `llama-server --version` probe; leaving it null keeps the downloader
  /// free of process execution. [clock] returns milliseconds since the epoch
  /// and is injectable so progress throttling can be tested without waiting.
  factory RuntimeDownloader({
    required RuntimeFetcher fetcher,
    ArchiveExtractor extractor = const ArchiveExtractor(),
    int Function() clock = _defaultClock,
    ProcessExecutor? executor,
  }) => RuntimeDownloader._(fetcher, extractor, clock, executor);

  RuntimeDownloader._(
    this._fetcher,
    this._extractor,
    this._clock,
    this._executor,
  );

  static const int _progressIntervalMs = 200;
  static const String _partName = 'asset.part';
  static const String _payloadName = 'payload';
  static const String _cudartName = 'cudart';

  final RuntimeFetcher _fetcher;
  final ArchiveExtractor _extractor;
  final int Function() _clock;
  final ProcessExecutor? _executor;

  /// Downloads [asset] into [targetParent] and returns the extracted payload.
  ///
  /// [targetParent] must be missing, empty, or hold only a resumable
  /// `asset.part`; it is created when missing. The caller normally passes a
  /// `runtime/.tmp-<uuid>` directory.
  ///
  /// With [resume], a leftover `asset.part` is continued when the server
  /// honours the range request and reports the same start offset. A server
  /// that answers `200`, or a `206` starting somewhere else, makes the
  /// download restart from zero. [onProgress] is called at most every ~200 ms
  /// and once at the end.
  Future<RuntimeInstallResult> download({
    required RuntimeAsset asset,
    required Directory targetParent,
    required void Function(RuntimeProgress) onProgress,
    RuntimeCancelToken? cancel,
    bool resume = true,
  }) async {
    _throwIfCancelled(cancel);
    await _prepareTarget(targetParent);
    final payload = Directory(p.join(targetParent.path, _payloadName));
    final part = File(p.join(targetParent.path, _partName));

    try {
      final cudart = asset.cudartAsset;
      final totalBytes = asset.sizeBytes + (cudart?.sizeBytes ?? 0);
      await _downloadAsset(
        asset: asset,
        part: part,
        onProgress: onProgress,
        cancel: cancel,
        resume: resume,
        totalBytes: totalBytes,
        progressBase: 0,
      );
      var files = await _extract(part, asset.assetName, payload);
      await _deleteFile(part);

      final assets = <RuntimeAsset>[asset];
      if (cudart != null) {
        final scratch = Directory(p.join(targetParent.path, _cudartName));
        await scratch.create(recursive: true);
        final cudartPart = File(p.join(scratch.path, _partName));
        try {
          await _downloadAsset(
            asset: cudart,
            part: cudartPart,
            onProgress: onProgress,
            cancel: cancel,
            resume: resume,
            totalBytes: totalBytes,
            progressBase: asset.sizeBytes,
          );
          files += await _extract(cudartPart, cudart.assetName, payload);
        } finally {
          await _deleteDirectory(scratch);
        }
        assets.add(cudart);
      }

      final probe = await _probe(payload, asset.platform);
      return RuntimeInstallResult(
        tag: asset.tag,
        backend: asset.backend,
        platform: asset.platform,
        assetName: asset.assetName,
        sha256: asset.sha256,
        sizeBytes: asset.sizeBytes,
        payloadDir: payload,
        files: files,
        assets: assets,
        buildId: probe.buildId ?? _buildIdFromName(asset.assetName),
        commit: probe.commit,
        serverVersion: probe.version,
        buildNumber: probe.buildNumber,
      );
    } on Object catch (error) {
      final wasCancelled = cancel?.isCancelled ?? false;
      if (wasCancelled) {
        await _removeArtifacts(targetParent, payload);
        throw const RuntimeException(
          RuntimeFailureCode.cancelled,
          'the runtime download was cancelled',
        );
      }
      if (error is RuntimeException) {
        if (error.code == RuntimeFailureCode.cancelled) {
          await _removeArtifacts(targetParent, payload);
          rethrow;
        }
        if (error.code == RuntimeFailureCode.network) {
          // The partial file is the point of resuming; leave it in place.
          rethrow;
        }
        await _removeArtifacts(targetParent, payload);
        rethrow;
      }
      await _removeArtifacts(targetParent, payload);
      throw RuntimeException(
        RuntimeFailureCode.unknown,
        'runtime install failed: $error',
        cause: error,
      );
    }
  }

  Future<void> _prepareTarget(Directory targetParent) async {
    if (await targetParent.exists()) {
      final children = await targetParent.list().toList();
      // A partial archive is the point of resuming: an interrupted download
      // leaves exactly one there and a retry must be able to continue it.
      // Anything else means the caller reused a staging directory by mistake.
      for (final child in children) {
        final name = p.basename(child.path);
        if (name == _partName && child is File) {
          continue;
        }
        throw StateError('staging directory ${targetParent.path} is not empty');
      }
      return;
    }
    await targetParent.create(recursive: true);
  }

  Future<void> _downloadAsset({
    required RuntimeAsset asset,
    required File part,
    required void Function(RuntimeProgress) onProgress,
    required RuntimeCancelToken? cancel,
    required bool resume,
    required int totalBytes,
    required int progressBase,
  }) async {
    _throwIfCancelled(cancel);
    await part.parent.create(recursive: true);

    var existing = 0;
    if (resume && await part.exists()) {
      existing = await part.length();
    }
    if (existing <= 0 || existing >= asset.sizeBytes) {
      existing = 0;
    }

    var response = await _open(asset.url, existing, cancel);
    var resuming = false;

    if (response.statusCode == 206 &&
        existing > 0 &&
        (response.contentRangeStart == null ||
            response.contentRangeStart == existing)) {
      // A 206 without Content-Range is taken at face value; the SHA-256 below
      // is the backstop if the server really started somewhere else.
      resuming = true;
    } else if (response.statusCode == 206 && existing > 0) {
      // A range starting anywhere but where we asked cannot be appended.
      await _discard(response.bytes);
      response = await _open(asset.url, 0, cancel);
      if (response.statusCode != 200) {
        await _discard(response.bytes);
        throw RuntimeException(
          RuntimeFailureCode.httpStatus,
          'GET ${asset.url} answered HTTP ${response.statusCode} after a '
          'range restart',
          actual: response.statusCode,
        );
      }
    } else if (response.statusCode != 200) {
      await _discard(response.bytes);
      throw RuntimeException(
        RuntimeFailureCode.httpStatus,
        'GET ${asset.url} answered HTTP ${response.statusCode}',
        actual: response.statusCode,
      );
    }

    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    var downloaded = 0;
    var received = progressBase;
    if (resuming) {
      downloaded = existing;
      received = progressBase + downloaded;
      try {
        await for (final chunk in part.openRead()) {
          _throwIfCancelled(cancel);
          hasher.add(chunk);
        }
      } on RuntimeException {
        rethrow;
      } on Object catch (error) {
        throw RuntimeException(
          RuntimeFailureCode.extraction,
          'could not read the partial archive ${part.path}: $error',
          cause: error,
        );
      }
    }

    final stopwatch = Stopwatch()..start();
    var sessionBytes = 0;
    var lastEmit = _clock();
    onProgress(
      RuntimeProgress(received: received, total: totalBytes, bytesPerSecond: 0),
    );

    void emit({required bool force}) {
      final now = _clock();
      if (!force && now - lastEmit < _progressIntervalMs) {
        return;
      }
      lastEmit = now;
      final micros = stopwatch.elapsedMicroseconds;
      final seconds = micros <= 0 ? 0.000001 : micros / 1000000;
      onProgress(
        RuntimeProgress(
          received: received,
          total: totalBytes,
          bytesPerSecond: sessionBytes / seconds,
        ),
      );
    }

    final file = await part.open(
      mode: resuming ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in response.bytes) {
        _throwIfCancelled(cancel);
        if (chunk.isEmpty) {
          continue;
        }
        await file.writeFrom(chunk);
        hasher.add(chunk);
        downloaded += chunk.length;
        received = progressBase + downloaded;
        sessionBytes += chunk.length;
        if (downloaded > asset.sizeBytes) {
          throw RuntimeException(
            RuntimeFailureCode.sizeMismatch,
            '${asset.assetName} sent more than the pinned size',
            expected: asset.sizeBytes,
            actual: downloaded,
          );
        }
        emit(force: false);
      }
      emit(force: true);
    } on Object catch (error) {
      final cancelled = cancel?.isCancelled ?? false;
      if (cancelled) {
        await _deleteFile(part);
        throw const RuntimeException(
          RuntimeFailureCode.cancelled,
          'the runtime download was cancelled',
        );
      }
      if (error is RuntimeException) {
        if (error.code == RuntimeFailureCode.sizeMismatch) {
          await _deleteFile(part);
        }
        rethrow;
      }
      if (error is FileSystemException) {
        await _deleteFile(part);
        throw RuntimeException(
          RuntimeFailureCode.extraction,
          'could not write the archive to ${part.path}: $error',
          cause: error,
        );
      }
      throw RuntimeException(
        RuntimeFailureCode.network,
        'downloading ${asset.assetName} failed: $error',
        cause: error,
      );
    } finally {
      await file.close();
    }

    _throwIfCancelled(cancel);
    hasher.close();
    final actualDigest = digestSink.value?.toString() ?? '';
    final expectedDigest = asset.sha256.trim().toLowerCase();
    if (downloaded != asset.sizeBytes) {
      await _deleteFile(part);
      throw RuntimeException(
        RuntimeFailureCode.sizeMismatch,
        '${asset.assetName} is ${asset.sizeBytes} bytes but $downloaded '
        'arrived',
        expected: asset.sizeBytes,
        actual: downloaded,
      );
    }
    if (actualDigest != expectedDigest) {
      await _deleteFile(part);
      throw RuntimeException(
        RuntimeFailureCode.checksumMismatch,
        '${asset.assetName} failed SHA-256 verification',
        expected: expectedDigest,
        actual: actualDigest,
      );
    }
  }

  Future<RuntimeFetchResponse> _open(
    String url,
    int existing,
    RuntimeCancelToken? cancel,
  ) async {
    final uri = Uri.parse(url);
    try {
      return await _fetcher.open(
        uri,
        resumeFrom: existing > 0 ? existing : null,
        cancel: cancel,
      );
    } on RuntimeException {
      rethrow;
    } on Object catch (error) {
      throw RuntimeException(
        RuntimeFailureCode.network,
        'could not open $uri: $error',
        cause: error,
      );
    }
  }

  Future<int> _extract(
    File archive,
    String assetName,
    Directory payload,
  ) async {
    try {
      return await _extractor.extract(
        archive: archive,
        assetName: assetName,
        destination: payload,
      );
    } on RuntimeException {
      rethrow;
    } on Object catch (error) {
      throw RuntimeException(
        RuntimeFailureCode.extraction,
        'could not extract $assetName: $error',
        cause: error,
      );
    }
  }

  Future<_ProbeResult> _probe(
    Directory payload,
    RuntimePlatform platform,
  ) async {
    final executor = _executor;
    if (executor == null) {
      return const _ProbeResult();
    }
    final server = _findServer(payload, platform);
    if (server == null) {
      return const _ProbeResult();
    }
    try {
      final info = await ServerVersionParser(executor).parse(server.path);
      return _ProbeResult(
        version: info.version == 'unknown' ? null : info.version,
        buildNumber: info.buildNumber,
        commit: info.commit,
        buildId: info.buildNumber == null ? null : 'b${info.buildNumber}',
      );
    } on Object {
      // Probing is informational; a broken binary must not fail an install.
      return const _ProbeResult();
    }
  }

  static File? _findServer(Directory payload, RuntimePlatform platform) {
    final exact = File(p.join(payload.path, platform.serverBinaryName));
    if (exact.existsSync()) {
      return exact;
    }
    try {
      for (final entity in payload.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File &&
            p.basename(entity.path) == platform.serverBinaryName) {
          return entity;
        }
      }
    } on Object {
      // A missing or unreadable payload means there is nothing to probe.
    }
    return null;
  }

  static String? _buildIdFromName(String assetName) {
    final match = RegExp(r'\bb(\d+)\b').firstMatch(assetName);
    return match == null ? null : 'b${match.group(1)}';
  }

  Future<void> _removeArtifacts(
    Directory targetParent,
    Directory payload,
  ) async {
    await _deleteFile(File(p.join(targetParent.path, _partName)));
    await _deleteDirectory(Directory(p.join(targetParent.path, _cudartName)));
    await _deleteDirectory(payload);
  }

  static Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // A concurrent cleanup or an open handle wins; nothing else to do.
    }
  }

  static Future<void> _deleteDirectory(Directory directory) async {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException {
      // A concurrent cleanup or an open handle wins; nothing else to do.
    }
  }

  static Future<void> _discard(Stream<List<int>> bytes) async {
    final subscription = bytes.listen((_) {}, onError: (Object _) {});
    await subscription.cancel();
  }

  static void _throwIfCancelled(RuntimeCancelToken? cancel) {
    if (cancel?.isCancelled ?? false) {
      throw const RuntimeException(
        RuntimeFailureCode.cancelled,
        'the runtime download was cancelled',
      );
    }
  }

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

final class _ProbeResult {
  const _ProbeResult({
    this.version,
    this.buildNumber,
    this.commit,
    this.buildId,
  });

  final String? version;
  final int? buildNumber;
  final String? commit;
  final String? buildId;
}
