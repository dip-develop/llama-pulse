import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../bloc/inference_bloc.dart';
import '../bloc/inference_state.dart';

/// Latest throughput and timing numbers for the current or last request.
class MetricsPanel extends StatelessWidget {
  const MetricsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const ValueKey('metrics-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metrics', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child:
                  BlocSelector<
                    InferenceBloc,
                    InferenceState,
                    (BuiltList<GenerationMetrics>, int?)
                  >(
                    selector: (InferenceState state) =>
                        (state.metricsHistory, state.timeToFirstTokenMs),
                    builder:
                        (
                          BuildContext context,
                          (BuiltList<GenerationMetrics>, int?) data,
                        ) {
                          final (
                            BuiltList<GenerationMetrics> history,
                            int? timeToFirstTokenMs,
                          ) = data;
                          if (history.isEmpty) {
                            return const _EmptyState(
                              message:
                                  'Metrics appear here after a generation.',
                            );
                          }
                          final GenerationMetrics metrics = history.last;
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _MetricRow(
                                  label: 'Tokens/sec',
                                  value:
                                      '${metrics.tokensPerSecond.toStringAsFixed(1)}'
                                      ' tok/s',
                                ),
                                _MetricRow(
                                  label: 'Prompt eval',
                                  value: '${metrics.promptEvalMs} ms',
                                ),
                                _MetricRow(
                                  label: 'Generated tokens',
                                  value: '${metrics.generatedTokenCount}',
                                ),
                                _MetricRow(
                                  label: 'Prompt tokens',
                                  value: '${metrics.promptTokenCount}',
                                ),
                                if (timeToFirstTokenMs != null)
                                  _MetricRow(
                                    label: 'Time to first token',
                                    value: '$timeToFirstTokenMs ms',
                                  ),
                                _MetricRow(
                                  label: 'Reports',
                                  value: '${history.length} samples',
                                ),
                              ],
                            ),
                          );
                        },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.speed_outlined,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
