import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  group('ServerConfig', () {
    test('defaults describe a loopback server with no model', () {
      final config = ServerConfig.defaults();

      expect(ServerConfig.schemaVersion, 1);
      expect(config.modelPath, '');
      expect(config.host, '127.0.0.1');
      expect(config.port, 8080);
      expect(config.contextSize, 4096);
      expect(config.threads, 4);
      expect(config.gpuLayers, 0);
      expect(config.parallelSlots, 1);
      expect(config.modelAlias, 'llama-pulse');
      expect(config.apiKey, '');
      expect(config.flashAttention, ServerFlashAttention.auto);
      expect(config.mlock, isFalse);
      expect(config.mmap, isTrue);
      expect(config.extraArgs, isEmpty);
      expect(config.binaryPath, '');
      expect(config.startupTimeoutSeconds, 120);
    });

    test('copyWith replaces only the given fields', () {
      final original = ServerConfig.defaults();
      final changed = original.copyWith(
        modelPath: '/models/x.gguf',
        host: '0.0.0.0',
        port: 9000,
        contextSize: 8192,
        threads: 8,
        gpuLayers: 12,
        parallelSlots: 2,
        modelAlias: 'local',
        apiKey: 'secret',
        flashAttention: ServerFlashAttention.on,
        mlock: true,
        mmap: false,
        extraArgs: BuiltList<String>(['--mlock']),
        binaryPath: '/opt/llama-server',
        startupTimeoutSeconds: 30,
      );

      expect(original.modelPath, '');
      expect(original.host, '127.0.0.1');
      expect(original.port, 8080);
      expect(original.extraArgs, isEmpty);
      expect(original.flashAttention, ServerFlashAttention.auto);

      expect(changed.modelPath, '/models/x.gguf');
      expect(changed.host, '0.0.0.0');
      expect(changed.port, 9000);
      expect(changed.contextSize, 8192);
      expect(changed.threads, 8);
      expect(changed.gpuLayers, 12);
      expect(changed.parallelSlots, 2);
      expect(changed.modelAlias, 'local');
      expect(changed.apiKey, 'secret');
      expect(changed.flashAttention, ServerFlashAttention.on);
      expect(changed.mlock, isTrue);
      expect(changed.mmap, isFalse);
      expect(changed.extraArgs, ['--mlock']);
      expect(changed.binaryPath, '/opt/llama-server');
      expect(changed.startupTimeoutSeconds, 30);
    });

    test('copyWith keeps the extra arguments when it is not given', () {
      final config = ServerConfig.defaults().copyWith(
        extraArgs: BuiltList<String>(['--no-warmup']),
      );

      expect(config.copyWith(port: 9000).extraArgs, ['--no-warmup']);
    });

    test('clientHost and baseUrl use loopback for 127.0.0.1', () {
      final config = ServerConfig.defaults().copyWith(port: 1234);

      expect(config.clientHost, '127.0.0.1');
      expect(config.baseUrl, 'http://127.0.0.1:1234/v1');
    });

    test('clientHost maps a wildcard bind address to loopback', () {
      for (final host in ['0.0.0.0', '::', '[::]']) {
        final config = ServerConfig.defaults().copyWith(host: host);

        expect(config.clientHost, '127.0.0.1', reason: host);
        expect(config.baseUrl, 'http://127.0.0.1:8080/v1', reason: host);
      }
    });

    test('clientHost keeps an explicit host', () {
      final config = ServerConfig.defaults().copyWith(host: '192.168.1.10');

      expect(config.clientHost, '192.168.1.10');
      expect(config.baseUrl, 'http://192.168.1.10:8080/v1');
    });

    test('exposedOnNonLoopback is false for loopback binds', () {
      for (final host in ['127.0.0.1', 'localhost', '::1', '[::1]']) {
        expect(
          ServerConfig.defaults().copyWith(host: host).exposedOnNonLoopback,
          isFalse,
          reason: host,
        );
      }
    });

    test('exposedOnNonLoopback is true for wildcard and LAN binds', () {
      for (final host in ['0.0.0.0', '::', '[::]', '192.168.1.10']) {
        expect(
          ServerConfig.defaults().copyWith(host: host).exposedOnNonLoopback,
          isTrue,
          reason: host,
        );
      }
    });
  });

  group('ServerState', () {
    test('stopped has no process and no failure', () {
      final state = ServerState.stopped(updatedAtEpochMs: 42);

      expect(state.phase, ServerPhase.stopped);
      expect(state.health, ServerHealth.unknown);
      expect(state.supervisorPid, isNull);
      expect(state.serverPid, isNull);
      expect(state.startedAtEpochMs, isNull);
      expect(state.lastExitCode, isNull);
      expect(state.failure, isNull);
      expect(state.updatedAtEpochMs, 42);
      expect(state.isActive, isFalse);
    });

    test('isActive covers starting, running and stopping', () {
      final base = ServerState.stopped(updatedAtEpochMs: 1);
      for (final phase in [
        ServerPhase.starting,
        ServerPhase.running,
        ServerPhase.stopping,
      ]) {
        expect(base.rebuild((b) => b..phase = phase).isActive, isTrue);
      }
      expect(
        base.rebuild((b) => b..phase = ServerPhase.failed).isActive,
        isFalse,
      );
    });

    test('baseUrl maps a wildcard bind address to loopback', () {
      final state = ServerState.stopped(updatedAtEpochMs: 1).rebuild(
        (b) => b
          ..host = '0.0.0.0'
          ..port = 9100,
      );

      expect(state.baseUrl, 'http://127.0.0.1:9100/v1');
    });
  });

  group('ServerMetrics', () {
    test('empty zeroes every counter', () {
      final metrics = ServerMetrics.empty(7);

      expect(metrics.promptTokensTotal, 0);
      expect(metrics.tokensPredictedTotal, 0);
      expect(metrics.tokensPerSecond, 0);
      expect(metrics.promptTokensPerSecond, 0);
      expect(metrics.totalSlots, 0);
      expect(metrics.uptimeSeconds, isNull);
      expect(metrics.contextUsageRatio, isNull);
      expect(metrics.capturedAtEpochMs, 7);
    });
  });

  group('ServerProbeResult', () {
    test('carries the probe outcome', () {
      const result = ServerProbeResult(ok: true, latencyMs: 3, message: 'ok');

      expect(result.ok, isTrue);
      expect(result.latencyMs, 3);
      expect(result.message, 'ok');
    });
  });
}
