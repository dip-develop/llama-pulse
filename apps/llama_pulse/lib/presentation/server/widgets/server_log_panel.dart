import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../bloc/server_bloc.dart';
import '../bloc/server_dashboard_state.dart';
import '../bloc/server_event.dart';

/// Tail of the supervisor and `llama-server` output.
///
/// The panel follows the newest line, so a start failure stays visible without
/// the user scrolling. The scroll position lives here and not in the bloc:
/// presentation state does not belong in the domain snapshot.
class ServerLogPanel extends StatefulWidget {
  const ServerLogPanel({super.key});

  @override
  State<ServerLogPanel> createState() => _ServerLogPanelState();
}

class _ServerLogPanelState extends State<ServerLogPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return BlocListener<ServerBloc, ServerDashboardState>(
      listenWhen: (
        ServerDashboardState previous,
        ServerDashboardState current,
      ) => previous.logs != current.logs,
      listener: (BuildContext context, ServerDashboardState state) {
        // Only grow the view when a line was appended; clearing keeps the top.
        if (state.logs.length > 1) {
          _scrollToEnd();
        }
      },
      child: Card(
        key: const ValueKey('server-log-panel'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Log', style: theme.textTheme.titleMedium),
                  ),
                  TextButton(
                    key: const ValueKey('server-clear-logs'),
                    onPressed: () => context.read<ServerBloc>().add(
                      const ServerLogsCleared(),
                    ),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              Expanded(
                child:
                    BlocSelector<
                      ServerBloc,
                      ServerDashboardState,
                      BuiltList<ServerLogEntry>
                    >(
                      selector: (ServerDashboardState state) => state.logs,
                      builder:
                          (
                            BuildContext context,
                            BuiltList<ServerLogEntry> logs,
                          ) {
                            if (logs.isEmpty) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  'No log lines yet.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            }
                            return SingleChildScrollView(
                              controller: _scrollController,
                              child: SelectableText(
                                logs
                                    .map((ServerLogEntry e) => e.line)
                                    .join('\n'),
                                key: const ValueKey('server-log-tail'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
