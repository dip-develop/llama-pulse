import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/platform/clipboard_service.dart';
import '../bloc/server_bloc.dart';
import '../bloc/server_dashboard_state.dart';
import '../bloc/server_event.dart';

/// Endpoint card: the OpenAI-compatible base URL, a copy action and a probe.
class ServerEndpointCard extends StatelessWidget {
  const ServerEndpointCard({super.key, required this.clipboard});

  /// Clipboard seam used by the copy button.
  final ClipboardService clipboard;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ServerBloc,
      ServerDashboardState,
      (String, int?, String?, bool)
    >(
      selector: (ServerDashboardState state) => (
        state.endpoint,
        state.connectionLatencyMs,
        state.connectionMessage,
        state.testingConnection,
      ),
      builder: (BuildContext context, (String, int?, String?, bool) data) {
        final (String endpoint, int? latencyMs, String? message, bool testing) =
            data;
        return _Card(
          endpoint: endpoint,
          latencyMs: latencyMs,
          message: message,
          testing: testing,
          clipboard: clipboard,
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.endpoint,
    required this.latencyMs,
    required this.message,
    required this.testing,
    required this.clipboard,
  });

  final String endpoint;
  final int? latencyMs;
  final String? message;
  final bool testing;
  final ClipboardService clipboard;

  String? get _result {
    if (latencyMs == null && message == null) {
      return null;
    }
    if (message == null || message == 'ok') {
      return 'Connected (${latencyMs ?? 0} ms)';
    }
    return latencyMs == null ? message : '$message ($latencyMs ms)';
  }

  bool get _connected => message == null || message == 'ok';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? result = _result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Endpoint', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SelectableText(
              endpoint,
              key: const ValueKey('server-endpoint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('server-copy-endpoint'),
                  onPressed: () => unawaited(clipboard.setText(endpoint)),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('server-test-connection'),
                  onPressed: testing
                      ? null
                      : () => context.read<ServerBloc>().add(
                          const ServerTestConnectionRequested(),
                        ),
                  icon: const Icon(Icons.network_check, size: 18),
                  label: Text(testing ? 'Testing…' : 'Test connection'),
                ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text(
                result,
                key: const ValueKey('server-connection-result'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _connected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
