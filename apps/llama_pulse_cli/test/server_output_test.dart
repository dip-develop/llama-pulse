import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

ServerBinaryInfo _binary() => ServerBinaryInfo(
  (b) => b
    ..path = '/opt/llama-server'
    ..version = '0.8.0'
    ..buildNumber = 11960
    ..supported = true
    ..warning = null
    ..rawOutput = 'raw',
);

ServerFailure _failure() => ServerFailure(
  (b) => b
    ..code = ServerFailureCode.startupTimeout
    ..message = 'not ready'
    ..details = 'stderr',
);

ServerMetrics _metrics() => ServerMetrics(
  (b) => b
    ..promptTokensTotal = 10
    ..promptTokensCachedTotal = 2
    ..tokensPredictedTotal = 20
    ..nDecodeTotal = 3
    ..nTokensMax = 4
    ..requestsProcessing = 1
    ..requestsDeferred = 0
    ..nBusySlotsPerDecode = 1
    ..promptSecondsTotal = 0.5
    ..tokensPredictedSecondsTotal = 1.5
    ..tokensPerSecond = 20.0
    ..promptTokensPerSecond = 100.0
    ..activeSlots = 1
    ..totalSlots = 4
    ..uptimeSeconds = 42
    ..contextUsageRatio = 0.25
    ..capturedAtEpochMs = 1234,
);

ServerLogEntry _logEntry() => ServerLogEntry(
  (b) => b
    ..sequence = 12
    ..timestampEpochMs = 1700000000000
    ..stream = ServerLogStream.stdout
    ..line = 'hello',
);

void main() {
  test('encodeServerStatus uses the documented key set', () {
    final encoded = encodeServerStatus(
      ServerStatusSnapshot(
        running: true,
        status: 'running',
        health: 'ok',
        pid: 124,
        supervisorPid: 123,
        host: '127.0.0.1',
        port: 8080,
        baseUrl: 'http://127.0.0.1:8080/v1',
        modelPath: '/models/x.gguf',
        binary: _binary(),
        uptimeSeconds: 42,
        lastExitCode: null,
        failure: null,
      ),
    );

    expect(encoded.keys, [
      'schemaVersion',
      'type',
      'running',
      'status',
      'health',
      'pid',
      'supervisorPid',
      'host',
      'port',
      'baseUrl',
      'modelPath',
      'binary',
      'uptimeSeconds',
      'lastExitCode',
      'failure',
    ]);
    expect(encoded['type'], 'serverStatus');
    expect((encoded['binary']! as Map<String, Object?>).keys, [
      'path',
      'version',
      'buildNumber',
      'supported',
      'warning',
    ]);
  });

  test('encodeServerStatus keeps nullable fields when nothing is recorded', () {
    final encoded = encodeServerStatus(
      const ServerStatusSnapshot(
        running: false,
        status: 'stopped',
        health: 'unknown',
        pid: null,
        supervisorPid: null,
        host: '127.0.0.1',
        port: 8080,
        baseUrl: 'http://127.0.0.1:8080/v1',
        modelPath: '',
        binary: null,
        uptimeSeconds: null,
        lastExitCode: null,
        failure: null,
      ),
    );

    expect(encoded['binary'], isNull);
    expect(encoded['failure'], isNull);
    expect(encoded['pid'], isNull);
  });

  test('encodeServerMetrics has exactly the server metric keys', () {
    final encoded = encodeServerMetrics(_metrics());

    expect(encoded.keys, [
      'tokensPerSecond',
      'promptTokensPerSecond',
      'activeSlots',
      'totalSlots',
      'requestsProcessing',
      'requestsDeferred',
      'promptTokensTotal',
      'tokensPredictedTotal',
      'contextUsageRatio',
      'uptimeSeconds',
      'capturedAtEpochMs',
    ]);
    expect(encoded['tokensPerSecond'], 20.0);
    expect(encoded['contextUsageRatio'], 0.25);
  });

  test('serve event encoders use the documented key sets', () {
    expect(
      encodeServeStarting(
        supervisorPid: 123,
        modelPath: '/models/x.gguf',
        host: '127.0.0.1',
        port: 8080,
        binaryPath: '/opt/llama-server',
        binaryVersion: '0.8.0',
      ).keys,
      [
        'schemaVersion',
        'type',
        'supervisorPid',
        'modelPath',
        'host',
        'port',
        'binaryPath',
        'binaryVersion',
      ],
    );
    expect(
      encodeServeReady(
        serverPid: 124,
        baseUrl: 'http://127.0.0.1:8080/v1',
        startupMs: 1234,
      ).keys,
      ['schemaVersion', 'type', 'serverPid', 'baseUrl', 'startupMs'],
    );
    expect(encodeServeMetrics(_metrics()).keys, [
      'schemaVersion',
      'type',
      'metrics',
    ]);
    expect(encodeServeLog(_logEntry()).keys, [
      'schemaVersion',
      'type',
      'stream',
      'line',
    ]);
    expect(encodeServeStopping('sigint').keys, [
      'schemaVersion',
      'type',
      'reason',
    ]);
    expect(encodeServeStopped(0).keys, ['schemaVersion', 'type', 'exitCode']);
    final failed = encodeServeFailed(_failure(), 7);
    expect(failed.keys, ['schemaVersion', 'type', 'failure', 'lastExitCode']);
    expect((failed['failure']! as Map<String, Object?>).keys, [
      'code',
      'message',
      'details',
    ]);
  });

  test('encodeLogEntry and encodeServerStop match the command schema', () {
    expect(encodeLogEntry(_logEntry()).keys, [
      'schemaVersion',
      'type',
      'sequence',
      'timestampEpochMs',
      'stream',
      'line',
    ]);
    expect(encodeServerStop(stopped: true, pid: 124, forced: false).keys, [
      'schemaVersion',
      'type',
      'stopped',
      'pid',
      'forced',
    ]);
  });
}
