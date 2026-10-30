import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../bloc/server_bloc.dart';
import '../bloc/server_dashboard_state.dart';
import '../bloc/server_event.dart';

/// Lifecycle card: what the supervisor runs, where it runs and how to control
/// it.
class ServerStatusCard extends StatelessWidget {
  const ServerStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ServerBloc,
      ServerDashboardState,
      (ServerState, ServerBinaryInfo?, bool)
    >(
      selector: (ServerDashboardState state) =>
          (state.serverState, state.binaryInfo, state.externalRun),
      builder:
          (BuildContext context, (ServerState, ServerBinaryInfo?, bool) data) {
            final (
              ServerState serverState,
              ServerBinaryInfo? binaryInfo,
              bool externalRun,
            ) = data;
            return _Card(
              serverState: serverState,
              binaryInfo: binaryInfo,
              externalRun: externalRun,
            );
          },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.serverState,
    required this.binaryInfo,
    required this.externalRun,
  });

  final ServerState serverState;
  final ServerBinaryInfo? binaryInfo;
  final bool externalRun;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ServerBinaryInfo? info = binaryInfo;
    final String binaryPath = info != null && info.path.isNotEmpty
        ? info.path
        : serverState.binaryPath;
    final String binaryVersion =
        info?.version ?? serverState.binaryVersion ?? '';
    final String? warning = info?.warning;
    final ServerFailure? failure = serverState.failure;
    return Card(
      key: const ValueKey('server-status-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Server', style: theme.textTheme.titleMedium),
                ),
                _StatusChip(serverState: serverState),
              ],
            ),
            const SizedBox(height: 12),
            _row(theme, 'Health', serverState.health.name),
            _row(
              theme,
              'Supervisor pid',
              serverState.supervisorPid?.toString() ?? '—',
            ),
            _row(theme, 'Server pid', serverState.serverPid?.toString() ?? '—'),
            _row(
              theme,
              'Model',
              serverState.modelPath.isEmpty ? '—' : serverState.modelPath,
            ),
            _row(
              theme,
              'Binary',
              binaryPath.isEmpty ? 'not located' : binaryPath,
            ),
            if (binaryVersion.isNotEmpty) _row(theme, 'Version', binaryVersion),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Text(
                warning,
                key: const ValueKey('server-binary-warning'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (externalRun)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Started outside this app — stop it with llamapulse stop.',
                  key: const ValueKey('server-external-run'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _row(theme, 'Uptime', _uptime(serverState)),
            _row(
              theme,
              'Last exit code',
              serverState.lastExitCode?.toString() ?? '—',
            ),
            if (failure != null)
              _row(
                theme,
                'Last failure',
                '${failure.code.name}: ${failure.message}',
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BlocSelector<ServerBloc, ServerDashboardState, bool>(
                  selector: (ServerDashboardState state) => state.canStart,
                  builder: (BuildContext context, bool canStart) {
                    return FilledButton.icon(
                      key: const ValueKey('server-start'),
                      onPressed: canStart
                          ? () => context.read<ServerBloc>().add(
                              const ServerStartRequested(),
                            )
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                    );
                  },
                ),
                BlocSelector<ServerBloc, ServerDashboardState, bool>(
                  selector: (ServerDashboardState state) => state.canStop,
                  builder: (BuildContext context, bool canStop) {
                    return OutlinedButton.icon(
                      key: const ValueKey('server-stop'),
                      onPressed: canStop
                          ? () => context.read<ServerBloc>().add(
                              const ServerStopRequested(),
                            )
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _uptime(ServerState state) {
    final int? startedAt = state.startedAtEpochMs;
    if (startedAt == null || !state.isActive) {
      return '—';
    }
    final int seconds =
        (DateTime.now().millisecondsSinceEpoch - startedAt) ~/ 1000;
    if (seconds < 0) {
      return '—';
    }
    if (seconds < 60) {
      return '${seconds}s';
    }
    final int minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '${minutes}m ${seconds % 60}s';
    }
    final int hours = minutes ~/ 60;
    return '${hours}h ${minutes % 60}m';
  }

  static Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.serverState});

  final ServerState serverState;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (String label, Color background, Color foreground) = _appearance(
      serverState.phase,
      theme.colorScheme,
    );
    return Container(
      key: const ValueKey('server-status-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label · ${serverState.health.name}',
        style: theme.textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }

  static (String, Color, Color) _appearance(
    ServerPhase phase,
    ColorScheme scheme,
  ) => switch (phase) {
    ServerPhase.running => (
      'Running',
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
    ),
    ServerPhase.starting => (
      'Starting',
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
    ),
    ServerPhase.stopping => (
      'Stopping',
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
    ),
    ServerPhase.failed => (
      'Failed',
      scheme.errorContainer,
      scheme.onErrorContainer,
    ),
    _ => ('Stopped', scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
  };
}
