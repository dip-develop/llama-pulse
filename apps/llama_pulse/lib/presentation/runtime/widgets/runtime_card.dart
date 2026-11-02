import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../bloc/runtime_bloc.dart';
import '../bloc/runtime_event.dart';
import '../bloc/runtime_state.dart';
import 'runtime_install_dialog.dart';

/// Compact runtime summary shown under the dashboard status card.
class RuntimeCard extends StatelessWidget {
  const RuntimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RuntimeBloc, RuntimeState>(
      builder: (BuildContext context, RuntimeState state) {
        final ThemeData theme = Theme.of(context);
        final RuntimeBackend? recommended = state.recommendedBackend;
        final RuntimeBackend? installing = state.installingBackend;
        return Card(
          key: const ValueKey('runtime-card'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Runtime', style: theme.textTheme.titleMedium),
                    if (recommended != null)
                      Chip(
                        key: const ValueKey('runtime-recommended-chip'),
                        label: Text('Recommended: ${recommended.displayName}'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _row(theme, 'Hardware', state.hardwareSummary ?? 'Detecting…'),
                _row(
                  theme,
                  'Selected',
                  state.selectedId == null
                      ? 'none'
                      : '${state.selectedId}'
                            '${state.selectedVersion == null ? '' : ' (${state.selectedVersion})'}',
                ),
                _row(theme, 'Installed', '${state.installed.length}'),
                if (state.gateVerdict != null)
                  _row(
                    theme,
                    'Gate',
                    '${state.gateVerdict!.name}'
                        '${state.gateReason == null ? '' : ' — ${state.gateReason}'}',
                  ),
                if (installing != null) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    key: const ValueKey('runtime-progress'),
                    value: state.progressFraction,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Installing ${installing.displayName}: '
                          '${(state.progressFraction * 100).floor()}%',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('runtime-cancel'),
                        onPressed: () => context.read<RuntimeBloc>().add(
                          const RuntimeCancelRequested(),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        FilledButton.tonal(
                          key: const ValueKey('runtime-install-button'),
                          onPressed: recommended == null || state.busy
                              ? null
                              : () => _install(context, recommended),
                          child: const Text('Install runtime'),
                        ),
                        if (state.selectedTag != null &&
                            state.selectedBackend != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            key: const ValueKey('runtime-remove'),
                            onPressed: state.busy
                                ? null
                                : () => _remove(
                                    context,
                                    state.selectedTag!,
                                    state.selectedBackend!,
                                  ),
                            child: const Text('Remove'),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      state.errorMessage!,
                      key: const ValueKey('runtime-error'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _install(BuildContext context, RuntimeBackend backend) async {
    final RuntimeBloc bloc = context.read<RuntimeBloc>();
    final bool confirmed = await confirmRuntimeInstall(
      context,
      bloc: bloc,
      backend: backend,
    );
    if (confirmed) {
      bloc.add(RuntimeInstallRequested(backend));
    }
  }

  Future<void> _remove(
    BuildContext context,
    String tag,
    RuntimeBackend backend,
  ) async {
    final RuntimeBloc bloc = context.read<RuntimeBloc>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        key: const ValueKey('runtime-remove-dialog'),
        title: Text('Remove $tag/${backend.id}?'),
        content: const Text(
          'The runtime directory and its manifest are deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('runtime-remove-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      bloc.add(RuntimeRemoveRequested(tag, backend));
    }
  }

  static Widget _row(ThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
