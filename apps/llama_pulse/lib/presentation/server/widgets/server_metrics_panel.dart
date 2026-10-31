import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../bloc/server_bloc.dart';
import '../bloc/server_dashboard_state.dart';

/// Live throughput, slot and context numbers from the running server.
class ServerMetricsPanel extends StatelessWidget {
  const ServerMetricsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const ValueKey('server-metrics-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Metrics', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            BlocSelector<
              ServerBloc,
              ServerDashboardState,
              BuiltList<ServerMetrics>
            >(
              selector: (ServerDashboardState state) => state.metricsHistory,
              builder:
                  (BuildContext context, BuiltList<ServerMetrics> history) {
                    if (history.isEmpty) {
                      return Text(
                        'Metrics appear once the server is running.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    return _MetricsList(metrics: history.last);
                  },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsList extends StatelessWidget {
  const _MetricsList({required this.metrics});

  final ServerMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final double? contextUsage = metrics.contextUsageRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetricRow(
          label: 'Generation',
          valueKey: 'server-metric-tokens-per-second',
          value: '${metrics.tokensPerSecond.toStringAsFixed(1)} tok/s',
        ),
        _MetricRow(
          label: 'Prompt',
          valueKey: 'server-metric-prompt-tokens-per-second',
          value: '${metrics.promptTokensPerSecond.toStringAsFixed(1)} tok/s',
        ),
        _MetricRow(
          label: 'Active slots',
          valueKey: 'server-metric-active-slots',
          value: '${metrics.activeSlots}/${metrics.totalSlots}',
        ),
        _MetricRow(
          label: 'Requests',
          valueKey: 'server-metric-requests',
          value:
              '${metrics.requestsProcessing} processing · '
              '${metrics.requestsDeferred} deferred',
        ),
        _MetricRow(
          label: 'Predicted tokens',
          valueKey: 'server-metric-predicted-tokens',
          value: '${metrics.tokensPredictedTotal}',
        ),
        _MetricRow(
          label: 'Uptime',
          valueKey: 'server-metric-uptime',
          value: _duration(metrics.uptimeSeconds),
        ),
        const SizedBox(height: 8),
        Text(
          'Context usage',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Column(
          key: const ValueKey('server-metric-context-usage'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contextUsage == null)
              Text(
                'not exposed',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              LinearProgressIndicator(
                value: contextUsage.clamp(0, 1).toDouble(),
              ),
              const SizedBox(height: 2),
              Text(
                '${(contextUsage * 100).clamp(0, 100).toStringAsFixed(1)} %',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String _duration(int? seconds) {
    if (seconds == null) {
      return '—';
    }
    if (seconds < 60) {
      return '${seconds}s';
    }
    final int minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '${minutes}m ${seconds % 60}s';
    }
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.valueKey,
    required this.value,
  });

  final String label;
  final String valueKey;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            key: ValueKey(valueKey),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
