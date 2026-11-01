import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../output.dart';

/// Version of the `runtime` command output schema.
const int runtimeOutputSchemaVersion = 1;

Map<String, Object?> _encodeInstallRef(RuntimeInstallRef install) => {
  'id': install.id,
  'tag': install.tag,
  'backend': install.backend.id,
  'platform': install.platform.id,
  'installedAtEpochMs': install.installedAtEpochMs,
  'sizeBytes': install.sizeBytes,
};

Map<String, Object?> _encodeGpu(RuntimeGpu gpu) => {
  'name': gpu.name,
  'vendor': gpu.vendor,
  'driverVersion': gpu.driverVersion,
  'memoryBytes': gpu.memoryBytes,
};

Map<String, Object?> _encodeBackend(
  RuntimeStatus status,
  RuntimeBackend backend,
) {
  final support = status.detection.supportFor(backend);
  final asset = status.release.forBackend(
    backend,
    status.detection.hardware.platform ?? RuntimePlatform.linuxX64,
  );
  return {
    'id': backend.id,
    'displayName': backend.displayName,
    'requires': backend.requires,
    'supported': support?.supported ?? false,
    'reason': support?.reason ?? 'not probed',
    'recommended': backend == status.recommendedBackend,
    'installed': status.index.installed.any(
      (install) => install.backend == backend,
    ),
    'downloadSizeBytes': asset?.sizeBytes,
    'cudartSizeBytes': asset?.cudartAsset?.sizeBytes,
  };
}

/// Encodes the object printed by `runtime status --json`.
Map<String, Object?> encodeRuntimeStatus(RuntimeStatus status) {
  final hardware = status.detection.hardware;
  final recommendation = status.detection.recommendation;
  final selected = status.selected;
  return {
    'schemaVersion': runtimeOutputSchemaVersion,
    'type': 'runtimeStatus',
    'release': {
      'tag': status.release.tag,
      'build': status.release.build,
      'commit': status.release.commit,
    },
    'host': {
      'operatingSystem': hardware.operatingSystem,
      'arch': hardware.arch,
      'platform': hardware.platform?.id,
      'cuda': hardware.hasCuda,
      'rocm': hardware.hasRocm,
      'vulkan': hardware.hasVulkan,
      'gpus': [for (final gpu in hardware.gpus) _encodeGpu(gpu)],
    },
    'recommendation': recommendation == null
        ? null
        : {
            'backend': recommendation.backend.id,
            'reason': recommendation.reason,
          },
    'selected': selected == null ? null : _encodeInstallRef(selected),
    'installed': [
      for (final install in status.installs) _encodeInstallRef(install),
    ],
    'gate': {
      'verdict': status.gate.wireName,
      'accepted': status.gate.accepted,
      'reason': status.gate.reason,
    },
    'backends': [
      for (final backend in status.offeredBackends)
        _encodeBackend(status, backend),
    ],
  };
}

/// Encodes the object printed by `runtime list --json`.
Map<String, Object?> encodeRuntimeList(RuntimeIndex index) {
  final selected = index.selected;
  return {
    'schemaVersion': runtimeOutputSchemaVersion,
    'type': 'runtimeList',
    'selected': selected == null ? null : _encodeInstallRef(selected),
    'installed': [
      for (final install in index.resolutionOrder) _encodeInstallRef(install),
    ],
  };
}

/// Encodes one `runtimeProgress` NDJSON line.
Map<String, Object?> encodeRuntimeProgress(
  RuntimeBackend backend,
  RuntimeProgress progress,
) => {
  'schemaVersion': runtimeOutputSchemaVersion,
  'type': 'runtimeProgress',
  'backend': backend.id,
  'received': progress.received,
  'total': progress.total,
  'fraction': double.parse(progress.fraction.toStringAsFixed(4)),
  'bytesPerSecond': progress.bytesPerSecond.round(),
};

/// Encodes the object printed by a successful `runtime install --json`.
Map<String, Object?> encodeRuntimeInstall(RuntimeInstallResult result) => {
  'schemaVersion': runtimeOutputSchemaVersion,
  'type': 'runtimeInstall',
  'tag': result.tag,
  'backend': result.backend.id,
  'platform': result.platform.id,
  'assetName': result.assetName,
  'sha256': result.sha256,
  'sizeBytes': result.sizeBytes,
  'files': result.files,
  'build': result.buildId,
  'llamaVersion': result.serverVersion,
  'directory': result.payloadDir.path,
};

/// Encodes a failed `runtime` command for `--json`.
Map<String, Object?> encodeRuntimeFailed({
  required String command,
  required String code,
  required String message,
  Object? expected,
  Object? actual,
}) => {
  'schemaVersion': runtimeOutputSchemaVersion,
  'type': 'runtimeFailed',
  'command': command,
  'code': code,
  'message': message,
  'expected': expected,
  'actual': actual,
};

/// Formats a byte count as mebibytes with one decimal.
String formatRuntimeSize(int bytes) => '${formatSizeMiB(bytes)} MiB';
