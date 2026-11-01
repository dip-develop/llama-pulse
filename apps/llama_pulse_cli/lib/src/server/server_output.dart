import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../output.dart';
import 'server_status_reader.dart';

/// Version of the server command output schema.
const int serverOutputSchemaVersion = 1;

/// Encodes one catalog parameter with the documented field set.
///
/// The key order is part of the contract: `params catalog --json` and
/// `params describe --json` both use it, so consumers see the same object.
Map<String, Object?> encodeParameter(ParameterSpec spec) => {
  'id': spec.id,
  'displayName': spec.displayName,
  'flags': spec.flags,
  'negatedFlag': spec.negatedFlag,
  'type': spec.type.wireName,
  'arity': spec.arity,
  'defaultValue': spec.defaultValue,
  'min': spec.min,
  'max': spec.max,
  'allowed': spec.allowed,
  'itemType': spec.itemType?.wireName,
  'repeatable': spec.repeatable,
  'group': spec.group,
  'surfaces': [for (final surface in spec.surfaces) surface.wireName],
  'exposure': spec.exposure.wireName,
  'owner': spec.owner,
  'managedBy': spec.managedBy,
  'envVar': spec.envVar,
  'advanced': spec.advanced,
  'deprecated': spec.deprecated,
  'replacement': spec.replacement,
  'requiresExistingPath': spec.requiresExistingPath,
  'warning': spec.warning,
  'summary': spec.summary,
  'description': spec.description,
  'reason': spec.reason,
};

/// Encodes the object printed by `params catalog --json`.
///
/// [surface] is the requested filter (`all`, `server` or `embedded`), while
/// [parameters] and [groups] are the entries that survived it.
Map<String, Object?> encodeCatalog({
  required ParameterCatalog catalog,
  required String surface,
  required List<ParameterSpec> parameters,
  required List<ParameterGroupSpec> groups,
}) => {
  'schemaVersion': serverOutputSchemaVersion,
  'type': 'parameterCatalog',
  'surface': surface,
  'upstreamTag': catalog.upstreamTag,
  'count': parameters.length,
  'groups': [
    for (final group in groups)
      {
        'id': group.id,
        'name': group.name,
        'order': group.order,
        'defaultOpen': group.defaultOpen,
      },
  ],
  'parameters': [for (final spec in parameters) encodeParameter(spec)],
};

/// Returns the ids whose effective value differs from the default for
/// [config], in catalog order, with unknown stored ids last.
///
/// Typed fields are compared with the value of the same field on
/// [ServerConfig.defaults], so `threads: 8` is reported even though the
/// catalog default for `threads` is dynamic. Map-backed values use
/// [ParameterValueCodec.isDefault].
List<String> modifiedServerParameterIds(ServerConfig config) {
  final catalog = ParameterCatalog.v080;
  final defaults = ServerConfig.defaults();
  final ids = <String>[];
  final known = <String>{};
  for (final spec in catalog.parameters) {
    known.add(spec.id);
    if (!spec.appliesTo(ParamSurface.server)) {
      continue;
    }
    final value = ParameterValues.valueFor(config, spec.id);
    if (value == null || value.isEmpty) {
      continue;
    }
    final isDefault = spec.owner != null
        ? value == ParameterValues.valueFor(defaults, spec.id)
        : ParameterValueCodec.isDefault(spec, value);
    if (!isDefault) {
      ids.add(spec.id);
    }
  }
  final unknown = [
    for (final id in config.params.keys)
      if (!known.contains(id)) id,
  ]..sort();
  return [...ids, ...unknown];
}

/// Extends a `server.yaml` document with the additive `--json` keys.
Map<String, Object?> encodeServerDocument({
  required Map<String, Object?> document,
  required ServerConfig config,
}) => {
  ...document,
  'params': {for (final entry in config.params.entries) entry.key: entry.value},
  'modified': modifiedServerParameterIds(config),
};

/// Encodes [failure] as the nested failure object.
Map<String, Object?> encodeServerFailure(ServerFailure failure) => {
  'code': failure.code.name,
  'message': failure.message,
  'details': failure.details,
};

/// Encodes [binary] as the nested binary object.
Map<String, Object?> encodeServerBinary(ServerBinaryInfo binary) => {
  'path': binary.path,
  'version': binary.version,
  'buildNumber': binary.buildNumber,
  'supported': binary.supported,
  'warning': binary.warning,
};

/// Encodes the `serverStatus` object printed by `status --json`.
Map<String, Object?> encodeServerStatus(ServerStatusSnapshot snapshot) {
  final binary = snapshot.binary;
  final failure = snapshot.failure;
  return {
    'schemaVersion': serverOutputSchemaVersion,
    'type': 'serverStatus',
    'running': snapshot.running,
    'status': snapshot.status,
    'health': snapshot.health,
    'pid': snapshot.pid,
    'supervisorPid': snapshot.supervisorPid,
    'host': snapshot.host,
    'port': snapshot.port,
    'baseUrl': snapshot.baseUrl,
    'modelPath': snapshot.modelPath,
    'binary': binary == null ? null : encodeServerBinary(binary),
    'uptimeSeconds': snapshot.uptimeSeconds,
    'lastExitCode': snapshot.lastExitCode,
    'failure': failure == null ? null : encodeServerFailure(failure),
  };
}

/// Encodes [metrics] with the server-specific key set.
Map<String, Object?> encodeServerMetrics(ServerMetrics metrics) => {
  'tokensPerSecond': metrics.tokensPerSecond,
  'promptTokensPerSecond': metrics.promptTokensPerSecond,
  'activeSlots': metrics.activeSlots,
  'totalSlots': metrics.totalSlots,
  'requestsProcessing': metrics.requestsProcessing,
  'requestsDeferred': metrics.requestsDeferred,
  'promptTokensTotal': metrics.promptTokensTotal,
  'tokensPredictedTotal': metrics.tokensPredictedTotal,
  'contextUsageRatio': metrics.contextUsageRatio,
  'uptimeSeconds': metrics.uptimeSeconds,
  'capturedAtEpochMs': metrics.capturedAtEpochMs,
};

/// Encodes the `starting` event emitted by `serve --json`.
Map<String, Object?> encodeServeStarting({
  required int? supervisorPid,
  required String modelPath,
  required String host,
  required int port,
  required String binaryPath,
  required String? binaryVersion,
}) => {
  'schemaVersion': serverOutputSchemaVersion,
  'type': 'starting',
  'supervisorPid': supervisorPid,
  'modelPath': modelPath,
  'host': host,
  'port': port,
  'binaryPath': binaryPath,
  'binaryVersion': binaryVersion,
};

/// Encodes the `ready` event emitted by `serve --json`.
Map<String, Object?> encodeServeReady({
  required int? serverPid,
  required String baseUrl,
  required int startupMs,
}) => {
  'schemaVersion': serverOutputSchemaVersion,
  'type': 'ready',
  'serverPid': serverPid,
  'baseUrl': baseUrl,
  'startupMs': startupMs,
};

/// Encodes the `metrics` event emitted by `serve --json`.
Map<String, Object?> encodeServeMetrics(ServerMetrics metrics) => {
  'schemaVersion': serverOutputSchemaVersion,
  'type': 'metrics',
  'metrics': encodeServerMetrics(metrics),
};

/// Encodes a `log` event emitted by `serve --json`.
Map<String, Object?> encodeServeLog(ServerLogEntry entry) => {
  'schemaVersion': serverOutputSchemaVersion,
  'type': 'log',
  'stream': entry.stream.name,
  'line': entry.line,
};

/// Encodes the `stopping` event emitted by `serve --json`.
Map<String, Object?> encodeServeStopping(String reason) => {
  'schemaVersion': serverOutputSchemaVersion,
  'type': 'stopping',
  'reason': reason,
};

/// Encodes the `stopped` event emitted by `serve --json`.
Map<String, Object?> encodeServeStopped(int exitCode) => {
  'schemaVersion': serverOutputSchemaVersion,
  'type': 'stopped',
  'exitCode': exitCode,
};

/// Encodes the `failed` event emitted by `serve --json`.
Map<String, Object?> encodeServeFailed(
  ServerFailure failure,
  int? lastExitCode,
) => {
  'schemaVersion': serverOutputSchemaVersion,
  'type': 'failed',
  'failure': encodeServerFailure(failure),
  'lastExitCode': lastExitCode,
};

/// Encodes a log line printed by `logs --json`.
Map<String, Object?> encodeLogEntry(ServerLogEntry entry) => {
  'schemaVersion': serverOutputSchemaVersion,
  'type': 'log',
  'sequence': entry.sequence,
  'timestampEpochMs': entry.timestampEpochMs,
  'stream': entry.stream.name,
  'line': entry.line,
};

/// Encodes the object printed by `stop --json`.
Map<String, Object?> encodeServerStop({
  required bool stopped,
  required int? pid,
  required bool forced,
}) => {
  'schemaVersion': serverOutputSchemaVersion,
  'type': 'serverStop',
  'stopped': stopped,
  'pid': pid,
  'forced': forced,
};

/// Writes a `server.yaml` document as YAML or as one-line JSON.
void writeServerDocument(
  StringSink sink,
  Map<String, Object?> document, {
  required bool json,
}) {
  if (json) {
    writeJsonLine(sink, document);
  } else {
    sink.write(YamlEncoder.encode(document));
  }
}
