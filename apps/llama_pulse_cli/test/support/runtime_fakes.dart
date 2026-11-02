import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:llama_pulse_core/llama_pulse_core.dart';

/// A [RuntimeProbe] that reports one fixed detection.
final class FakeRuntimeProbe implements RuntimeProbe {
  FakeRuntimeProbe({this.detection, this.onProbe});

  /// Returned by every [probe] call; defaults to a Linux x64 host with CUDA.
  RuntimeDetection? detection;

  /// Runs before the detection is returned, for example to cancel a download.
  void Function()? onProbe;

  int calls = 0;

  @override
  Future<RuntimeDetection> probe() async {
    calls++;
    onProbe?.call();
    return detection ?? FakeRuntimeProbe.linuxCuda();
  }

  /// A Linux x64 host with one NVIDIA GPU and the CPU as a fallback.
  static RuntimeDetection linuxCuda() => RuntimeDetection(
    hardware: RuntimeHardware(
      operatingSystem: 'linux',
      arch: 'x64',
      platform: RuntimePlatform.linuxX64,
      gpus: const <RuntimeGpu>[
        RuntimeGpu(
          name: 'NVIDIA GeForce RTX 4090',
          vendor: 'nvidia',
          driverVersion: '580.95',
        ),
      ],
      hasCuda: true,
    ),
    supports: const <BackendSupport>[
      BackendSupport(
        backend: RuntimeBackend.cpu,
        supported: true,
        reason: 'runs on the host CPU',
      ),
      BackendSupport(
        backend: RuntimeBackend.cuda13,
        supported: true,
        reason: 'nvidia driver 580.95 >= 580',
      ),
    ],
    recommendation: const RuntimeRecommendation(
      backend: RuntimeBackend.cuda13,
      reason: 'nvidia driver 580.95 >= 580',
    ),
  );

  /// A host the pinned release has no archive for.
  static RuntimeDetection unsupported() => RuntimeDetection(
    hardware: RuntimeHardware(
      operatingSystem: 'linux',
      arch: 'arm64',
      platform: null,
    ),
    supports: const <BackendSupport>[],
  );
}

/// A [RuntimeFetcher] that serves in-memory bytes without a socket.
final class FakeCliRuntimeFetcher implements RuntimeFetcher {
  FakeCliRuntimeFetcher({
    required this.body,
    this.routes = const <String, List<int>>{},
    this.chunkSize = 4096,
    this.onChunk,
    this.openError,
  });

  /// Bytes served for a request whose URL is not in [routes].
  final List<int> body;

  /// Bytes keyed by full URL, for installs with more than one archive.
  final Map<String, List<int>> routes;

  /// When set, [open] throws it instead of returning a response.
  final Object? openError;

  /// Largest chunk the body stream emits.
  final int chunkSize;

  /// Runs after every chunk with the bytes sent so far.
  final void Function(int sent, RuntimeCancelToken? cancel)? onChunk;

  final List<Uri> requests = <Uri>[];
  int closeCalls = 0;

  @override
  Future<RuntimeFetchResponse> open(
    Uri uri, {
    int? resumeFrom,
    RuntimeCancelToken? cancel,
  }) async {
    requests.add(uri);
    final error = openError;
    if (error != null) {
      throw error;
    }
    final start =
        resumeFrom != null && resumeFrom > 0 && resumeFrom < body.length
        ? resumeFrom
        : 0;
    final bytes = body.sublist(start);
    return RuntimeFetchResponse(
      statusCode: start > 0 ? 206 : 200,
      contentLength: bytes.length,
      etag: '"fake"',
      contentRangeStart: start > 0 ? start : null,
      bytes: _chunks(bytes, cancel),
    );
  }

  Stream<List<int>> _chunks(
    List<int> bytes,
    RuntimeCancelToken? cancel,
  ) async* {
    var sent = 0;
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = min(offset + chunkSize, bytes.length);
      final chunk = bytes.sublist(offset, end);
      yield chunk;
      sent += chunk.length;
      onChunk?.call(sent, cancel);
    }
  }

  @override
  void close() {
    closeCalls++;
  }
}

/// A [ProcessExecutor] that answers `llama-server --version` without a process.
final class FakeCliProcessExecutor implements ProcessExecutor {
  FakeCliProcessExecutor(this.output);

  final ProcessOutput output;
  final List<String> commands = <String>[];

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    commands.add('$executable ${arguments.join(' ')}');
    return output;
  }
}

/// Builds a minimal `.tar.gz` with one top-level directory.
///
/// The CLI tests need a payload the safe extractor accepts and whose byte
/// length the test can hash; writing the tar directly keeps the fixture free
/// of an archive dependency in this package.
List<int> buildRuntimeTarGz(Map<String, String> files) {
  final out = BytesBuilder();
  for (final entry in files.entries) {
    final name = entry.key;
    final body = utf8.encode(entry.value);
    final header = Uint8List(512);
    header.setAll(0, utf8.encode(name));
    header.setAll(100, _octal(0x1a4, 7)); // mode 0644
    header.setAll(108, _octal(0, 7)); // uid
    header.setAll(116, _octal(0, 7)); // gid
    header.setAll(124, _octal(body.length, 11)); // size
    header.setAll(136, _octal(0, 11)); // mtime
    header.setAll(148, '        '.codeUnits); // checksum placeholder
    header[156] = '0'.codeUnitAt(0); // regular file
    header.setAll(257, 'ustar\u0000'.codeUnits);
    header.setAll(263, '00'.codeUnits);
    final checksum = header.fold<int>(0, (sum, byte) => sum + byte);
    header.setAll(
      148,
      '${checksum.toRadixString(8).padLeft(6, '0')}\u0000 '.codeUnits,
    );
    out
      ..add(header)
      ..add(body);
    final padding = (512 - body.length % 512) % 512;
    if (padding > 0) {
      out.add(Uint8List(padding));
    }
  }
  out.add(Uint8List(1024));
  return gzip.encode(out.takeBytes());
}

/// Encodes [value] as a NUL-terminated octal field of [width] digits.
List<int> _octal(int value, int width) =>
    '${value.toRadixString(8).padLeft(width - 1, '0')}\u0000'.codeUnits;
