import 'dart:convert';
import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

String _fixture(String name) =>
    File('test/data/server/fixtures/$name').readAsStringSync();

String _prometheusText() => _fixture('metrics.prom');

/// Drops the first, hand-written provenance line before decoding.
Object? _decodeFixture(String name) => jsonDecode(
  File('test/data/server/fixtures/$name').readAsLinesSync().skip(1).join('\n'),
);

List<Object?> _slots() {
  final decoded = _decodeFixture('slots.json');
  return decoded is List<Object?> ? decoded : const <Object?>[];
}

Map<String, Object?> _props() {
  final decoded = _decodeFixture('props.json');
  if (decoded is! Map<Object?, Object?>) {
    return const <String, Object?>{};
  }
  return decoded.map<String, Object?>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

ServerConfig _config({int contextSize = 4096}) => ServerConfig(
  (b) => b
    ..modelPath = '/models/model.gguf'
    ..host = '127.0.0.1'
    ..port = 8080
    ..contextSize = contextSize
    ..threads = 4
    ..gpuLayers = 0
    ..parallelSlots = 2
    ..modelAlias = 'llama-pulse'
    ..apiKey = ''
    ..flashAttention = ServerFlashAttention.auto
    ..mlock = false
    ..mmap = true
    ..binaryPath = ''
    ..startupTimeoutSeconds = 120,
);

ServerMetrics _map({
  PrometheusMetrics? metrics,
  List<Object?> slots = const <Object?>[],
  Map<String, Object?> props = const <String, Object?>{},
  ServerConfig? config,
  int? startedAtEpochMs,
  int? processStartTimeUnixSeconds,
  int capturedAtEpochMs = 0,
}) => const ServerMetricsMapper().from(
  metrics: metrics ?? PrometheusMetrics.parse(_prometheusText()),
  slots: slots,
  props: props,
  config: config ?? _config(),
  startedAtEpochMs: startedAtEpochMs,
  processStartTimeUnixSeconds: processStartTimeUnixSeconds,
  capturedAtEpochMs: capturedAtEpochMs,
);

void main() {
  group('ServerMetricsMapper', () {
    test('maps the fixture snapshot', () {
      final mapped = _map(
        slots: _slots(),
        props: _props(),
        startedAtEpochMs: 1600000000000,
        processStartTimeUnixSeconds: 1700000000,
        capturedAtEpochMs: 1700000100000,
      );

      expect(mapped.promptTokensTotal, 42);
      expect(mapped.promptTokensCachedTotal, 12);
      expect(mapped.promptSecondsTotal, 1.2);
      expect(mapped.tokensPredictedTotal, 128);
      expect(mapped.tokensPredictedSecondsTotal, 3.5);
      expect(mapped.nDecodeTotal, 16);
      expect(mapped.nTokensMax, 2048);
      expect(mapped.requestsProcessing, 1);
      expect(mapped.requestsDeferred, 0);
      expect(mapped.nBusySlotsPerDecode, 1);
      expect(mapped.tokensPerSecond, closeTo(36.57, 1e-9));
      expect(mapped.promptTokensPerSecond, 35.0);
      expect(mapped.activeSlots, 1);
      expect(mapped.totalSlots, 2);
      expect(mapped.uptimeSeconds, 100);
      expect(mapped.contextUsageRatio, closeTo(350 / 4096, 1e-12));
      expect(mapped.capturedAtEpochMs, 1700000100000);
    });

    test('falls back to n_tokens_max when there are no slots', () {
      final mapped = _map(
        metrics: const PrometheusMetrics(<String, double>{
          'llamacpp:n_tokens_max': 2048,
        }),
      );

      expect(mapped.activeSlots, 0);
      expect(mapped.totalSlots, 0);
      expect(mapped.contextUsageRatio, 0.5);
    });

    test('reports no context ratio without slots or n_tokens_max', () {
      final mapped = _map(metrics: const PrometheusMetrics(<String, double>{}));

      expect(mapped.contextUsageRatio, isNull);
    });

    test('uses the process start header for uptime', () {
      final mapped = _map(
        processStartTimeUnixSeconds: 1700000000,
        startedAtEpochMs: 1600000000000,
        capturedAtEpochMs: 1700000100000,
      );

      expect(mapped.uptimeSeconds, 100);
    });

    test('falls back to the local start time for uptime', () {
      final mapped = _map(
        startedAtEpochMs: 1600000000000,
        capturedAtEpochMs: 1600000030000,
      );

      expect(mapped.uptimeSeconds, 30);
    });

    test('reports no uptime when neither start time is known', () {
      final mapped = _map(capturedAtEpochMs: 1700000100000);

      expect(mapped.uptimeSeconds, isNull);
    });

    test('clamps a future process start to zero uptime', () {
      final mapped = _map(
        processStartTimeUnixSeconds: 1700000200,
        capturedAtEpochMs: 1700000100000,
      );

      expect(mapped.uptimeSeconds, 0);
    });

    test('uses the slot count when props lack total_slots', () {
      final mapped = _map(slots: _slots(), props: const <String, Object?>{});

      expect(mapped.totalSlots, 2);
    });

    test('ignores malformed slot entries', () {
      final mapped = _map(
        slots: <Object?>[
          null,
          'slot',
          42,
          <String, Object?>{'is_processing': true, 'n_ctx': 'bad'},
          <String, Object?>{
            'is_processing': true,
            'n_ctx': 1000,
            'n_prompt_tokens': 900,
          },
        ],
      );

      expect(mapped.activeSlots, 2);
      expect(mapped.contextUsageRatio, 0.9);
    });

    test('accepts prompt_tokens when n_prompt_tokens is missing', () {
      final mapped = _map(
        slots: <Object?>[
          <String, Object?>{
            'is_processing': true,
            'n_ctx': 1000,
            'prompt_tokens': 250,
          },
        ],
      );

      expect(mapped.contextUsageRatio, 0.25);
    });

    test('counts prompt tokens when next_token is absent', () {
      final mapped = _map(
        slots: <Object?>[
          <String, Object?>{
            'is_processing': true,
            'n_ctx': 1000,
            'n_prompt_tokens': 250,
          },
        ],
      );

      expect(mapped.contextUsageRatio, 0.25);
    });

    test('clamps the context ratio to one', () {
      final mapped = _map(
        slots: <Object?>[
          <String, Object?>{
            'is_processing': true,
            'n_ctx': 4096,
            'n_prompt_tokens': 5000,
          },
        ],
      );

      expect(mapped.contextUsageRatio, 1.0);
    });

    test('clamps the n_tokens_max fallback to one', () {
      final mapped = _map(
        metrics: const PrometheusMetrics(<String, double>{
          'llamacpp:n_tokens_max': 10000,
        }),
      );

      expect(mapped.contextUsageRatio, 1.0);
    });
  });
}
