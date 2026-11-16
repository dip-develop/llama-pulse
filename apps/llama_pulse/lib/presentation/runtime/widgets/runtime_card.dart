import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../l10n/app_localizations.dart';
import '../bloc/runtime_bloc.dart';
import '../bloc/runtime_event.dart';
import '../bloc/runtime_messages.dart';
import '../bloc/runtime_state.dart';
import '../runtime_hardware_summary.dart';
import 'runtime_install_dialog.dart';

/// Compact runtime summary shown under the dashboard status card.
class RuntimeCard extends StatelessWidget {
  const RuntimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RuntimeBloc, RuntimeState>(
      builder: (BuildContext context, RuntimeState state) {
        final ThemeData theme = Theme.of(context);
        final AppLocalizations l10n = AppLocalizations.of(context)!;
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
                    Text(l10n.runtimeTitle, style: theme.textTheme.titleMedium),
                    if (recommended != null)
                      Chip(
                        key: const ValueKey('runtime-recommended-chip'),
                        label: Text(
                          l10n.runtimeRecommendedBackend(
                            recommended.displayName,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _row(
                  theme,
                  l10n.runtimeHardware,
                  runtimeHardwareSummary(l10n, state),
                ),
                _row(
                  theme,
                  l10n.runtimeSelected,
                  state.selectedId == null
                      ? l10n.runtimeNone
                      : '${state.selectedId}'
                            '${state.selectedVersion == null ? '' : ' (${state.selectedVersion})'}',
                ),
                _row(theme, l10n.runtimeInstalled, '${state.installed.length}'),
                if (state.gateVerdict != null)
                  _row(
                    theme,
                    l10n.runtimeGateLabel,
                    l10n.runtimeGateValue(
                      runtimeGateVerdictLabel(l10n, state.gateVerdict!),
                      state.gateReason ?? '',
                    ),
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
                          l10n.runtimeInstallingProgress(
                            installing.displayName,
                            (state.progressFraction * 100).floor(),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('runtime-cancel'),
                        onPressed: () => context.read<RuntimeBloc>().add(
                          const RuntimeCancelRequested(),
                        ),
                        child: Text(l10n.cancelAction),
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
                          child: Text(l10n.runtimeInstallRuntime),
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
                            child: Text(l10n.runtimeRemove),
                          ),
                        ],
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.runtimeManagedNote,
                    key: const ValueKey('runtime-managed-note'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (state.errorCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      runtimeErrorText(
                        l10n,
                        state.errorCode!,
                        state.errorDetail ?? '',
                      ),
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        key: const ValueKey('runtime-remove-dialog'),
        title: Text(l10n.runtimeRemoveTitle('$tag/${backend.id}')),
        content: Text(l10n.runtimeRemoveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            key: const ValueKey('runtime-remove-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.runtimeRemove),
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
          width: 118,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
