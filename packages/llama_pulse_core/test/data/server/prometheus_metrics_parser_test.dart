import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

String _fixture(String name) =>
    File('test/data/server/fixtures/$name').readAsStringSync();

void main() {
  group('PrometheusMetrics', () {
    test('parses every value of the fixture', () {
      final metrics = PrometheusMetrics.parse(_fixture('metrics.prom'));

      expect(metrics.get('llamacpp:prompt_tokens_total'), 42);
      expect(metrics.get('llamacpp:prompt_tokens_cached_total'), 12);
      expect(metrics.get('llamacpp:prompt_seconds_total'), 1.2);
      expect(metrics.get('llamacpp:tokens_predicted_total'), 128);
      expect(metrics.get('llamacpp:tokens_predicted_seconds_total'), 3.5);
      expect(metrics.get('llamacpp:n_decode_total'), 16);
      expect(metrics.get('llamacpp:n_tokens_max'), 2048);
      expect(metrics.get('llamacpp:prompt_tokens_seconds'), 35.0);
      expect(metrics.get('llamacpp:predicted_tokens_seconds'), 36.57);
      expect(metrics.get('llamacpp:requests_processing'), 1);
      expect(metrics.get('llamacpp:requests_deferred'), 0);
      expect(metrics.get('llamacpp:n_busy_slots_per_decode'), 1);
      expect(metrics.samples, hasLength(12));
    });

    test('ignores comments, HELP and TYPE lines', () {
      final metrics = PrometheusMetrics.parse('''
# HELP custom_metric A custom metric.
# TYPE custom_metric counter
# a free-form comment
''');

      expect(metrics.samples, isEmpty);
    });

    test('strips labels from the sample name', () {
      final metrics = PrometheusMetrics.parse(
        'llamacpp:requests_processing{slot="0"} 3',
      );

      expect(metrics.get('llamacpp:requests_processing'), 3);
      expect(metrics.samples.keys, ['llamacpp:requests_processing']);
    });

    test('strips labels whose value contains spaces', () {
      final metrics = PrometheusMetrics.parse('custom{a="b c"} 4');

      expect(metrics.get('custom'), 4);
    });

    test('keeps the last value of a duplicate name', () {
      final metrics = PrometheusMetrics.parse('custom 1\ncustom 2');

      expect(metrics.get('custom'), 2);
    });

    test('skips NaN and infinite values', () {
      final metrics = PrometheusMetrics.parse(
        'nan_metric NaN\nplus_inf +Inf\nminus_inf -Inf\nfinite 4',
      );

      expect(metrics.has('nan_metric'), isFalse);
      expect(metrics.has('plus_inf'), isFalse);
      expect(metrics.has('minus_inf'), isFalse);
      expect(metrics.samples, hasLength(1));
      expect(metrics.get('finite'), 4);
    });

    test('skips garbage lines', () {
      final metrics = PrometheusMetrics.parse(
        'garbage line\nname\nmetric not_a_number\n  \n\t\n',
      );

      expect(metrics.samples, isEmpty);
    });

    test('parses scientific notation', () {
      final metrics = PrometheusMetrics.parse('custom 1.5e3');

      expect(metrics.get('custom'), 1500);
    });

    test('returns an empty map for empty text', () {
      final metrics = PrometheusMetrics.parse('');

      expect(metrics.samples, isEmpty);
    });

    test('returns zero for a missing metric', () {
      const metrics = PrometheusMetrics(<String, double>{});

      expect(metrics.get('missing'), 0);
      expect(metrics.has('missing'), isFalse);
    });
  });
}
