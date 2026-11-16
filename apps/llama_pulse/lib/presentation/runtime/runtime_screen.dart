import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../l10n/app_localizations.dart';
import 'bloc/runtime_bloc.dart';
import 'bloc/runtime_event.dart';
import 'bloc/runtime_messages.dart';
import 'bloc/runtime_state.dart';
import 'runtime_hardware_summary.dart';
import 'widgets/runtime_install_dialog.dart';

/// Runtime tab: detected hardware, the pinned backends and installed runtimes.
///
/// The install dialog shows the download size and driver floor; a running
/// download can be cancelled and an install can be removed after a
/// confirmation.
class RuntimeScreen extends StatelessWidget {
  const RuntimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const ValueKey('runtime-screen'),
      child: BlocBuilder<RuntimeBloc, RuntimeState>(
        builder: (BuildContext context, RuntimeState state) {
          final AppLocalizations l10n = AppLocalizations.of(context)!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(state: state),
                if (state.installingBackend != null) ...[
                  const SizedBox(height: 16),
                  _Progress(state: state),
                ],
                if (state.errorCode != null) ...[
                  const SizedBox(height: 16),
                  _Banner(
                    key: const ValueKey('runtime-tab-error'),
                    message: runtimeErrorText(
                      l10n,
                      state.errorCode!,
                      state.errorDetail ?? '',
                    ),
                    error: true,
                  ),
                ],
                if (state.noticeCode != null) ...[
                  const SizedBox(height: 16),
                  _Banner(
                    key: const ValueKey('runtime-tab-notice'),
                    message: runtimeNoticeText(
                      l10n,
                      state.noticeCode!,
                      state.noticeDetail ?? '',
                    ),
                    error: false,
                  ),
                ],
                const SizedBox(height: 16),
                _Backends(state: state),
                const SizedBox(height: 16),
                _Installed(state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final RuntimeState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Card(
      key: const ValueKey('runtime-hardware-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.runtimeTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (state.loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                IconButton(
                  key: const ValueKey('runtime-refresh'),
                  tooltip: l10n.runtimeRefresh,
                  onPressed: state.busy
                      ? null
                      : () => context.read<RuntimeBloc>().add(
                          const RuntimeRefreshed(),
                        ),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.runtimeHeaderSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              runtimeHardwareSummary(l10n, state),
              key: const ValueKey('runtime-hardware-summary'),
              style: theme.textTheme.bodyMedium,
            ),
            if (state.recommendedBackend != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.runtimeRecommendedReason(
                    state.recommendedBackend!.displayName,
                    state.recommendationReason ?? '',
                  ),
                  key: const ValueKey('runtime-recommendation'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            if (state.platform == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.runtimeUnsupportedHost,
                  key: const ValueKey('runtime-unsupported'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final RuntimeState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final RuntimeBackend backend = state.installingBackend!;
    return Card(
      key: const ValueKey('runtime-tab-progress'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.runtimeInstalling(backend.displayName),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: state.progressFraction),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _progressText(l10n),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  key: const ValueKey('runtime-tab-cancel'),
                  onPressed: () => context.read<RuntimeBloc>().add(
                    const RuntimeCancelRequested(),
                  ),
                  child: Text(l10n.cancelAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The progress line: the percentage, the transferred bytes and, while the
  /// transfer runs, the current rate.
  String _progressText(AppLocalizations l10n) {
    final String base = l10n.runtimeProgressValue(
      (state.progressFraction * 100).floor(),
      _formatBytes(state.progressReceived),
      _formatBytes(state.progressTotal),
    );
    if (state.bytesPerSecond <= 0) {
      return base;
    }
    return '$base · ${l10n.runtimeProgressRate(_formatBytes(state.bytesPerSecond.round()))}';
  }
}

class _Backends extends StatelessWidget {
  const _Backends({required this.state});

  final RuntimeState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Card(
      key: const ValueKey('runtime-backends-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.runtimeAvailableBackends,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            if (state.offeredBackends.isEmpty)
              Text(l10n.runtimeNoBackendAvailable)
            else
              for (final backend in state.offeredBackends)
                _BackendRow(state: state, backend: backend),
          ],
        ),
      ),
    );
  }
}

class _BackendRow extends StatelessWidget {
  const _BackendRow({required this.state, required this.backend});

  final RuntimeState state;
  final RuntimeBackend backend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final BackendSupport? support = state.supportFor(backend);
    final bool supported = state.isSupported(backend);
    final bool installed = state.installed.any(
      (install) => install.backend == backend,
    );
    final bool recommended = state.recommendedBackend == backend;
    return Padding(
      key: ValueKey('runtime-backend-${backend.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      backend.displayName,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (recommended) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(l10n.runtimeRecommended),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                    if (installed) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(l10n.runtimeInstalled),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                Text(
                  supported
                      ? (support?.reason ?? backend.requires)
                      : l10n.runtimeUnavailable(
                          support?.reason ?? backend.requires,
                        ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: supported
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            key: ValueKey('runtime-install-${backend.id}'),
            onPressed: !supported || state.busy || state.installing
                ? null
                : () => _install(context),
            child: Text(
              installed ? l10n.runtimeReinstall : l10n.runtimeInstall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _install(BuildContext context) async {
    final RuntimeBloc bloc = context.read<RuntimeBloc>();
    final bool confirmed = await confirmRuntimeInstall(
      context,
      bloc: bloc,
      backend: backend,
    );
    if (confirmed) {
      bloc.add(
        RuntimeInstallRequested(
          backend,
          force: state.installed.any((install) => install.backend == backend),
        ),
      );
    }
  }
}

class _Installed extends StatelessWidget {
  const _Installed({required this.state});

  final RuntimeState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Card(
      key: const ValueKey('runtime-installed-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.runtimeManagedTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            if (state.installed.isEmpty)
              Text(l10n.runtimeNoRuntimesInstalled)
            else
              for (final install in state.installed)
                _InstalledRow(state: state, install: install),
            if (state.gateVerdict != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.runtimeGateSummary(
                    runtimeGateVerdictLabel(l10n, state.gateVerdict!),
                    state.gateReason ?? '',
                  ),
                  key: const ValueKey('runtime-gate'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: state.gateAccepted
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.runtimeManagedNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstalledRow extends StatelessWidget {
  const _InstalledRow({required this.state, required this.install});

  final RuntimeState state;
  final RuntimeInstallRef install;

  @override
  Widget build(BuildContext context) {
    final bool selected = state.selectedId == install.id;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Padding(
      key: ValueKey('runtime-installed-${install.tag}-${install.backend.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(selected ? Icons.check_circle : Icons.circle_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${install.id} · ${install.platform.id} · '
              '${_formatBytes(install.sizeBytes)}',
            ),
          ),
          TextButton(
            key: ValueKey('runtime-select-${install.backend.id}'),
            onPressed: selected || state.busy
                ? null
                : () => context.read<RuntimeBloc>().add(
                    RuntimeSelectRequested(install.tag, install.backend),
                  ),
            child: Text(selected ? l10n.runtimeSelected : l10n.runtimeSelect),
          ),
          TextButton(
            key: ValueKey('runtime-remove-${install.backend.id}'),
            onPressed: state.busy
                ? null
                : () => _confirmRemove(context, install),
            child: Text(l10n.runtimeRemove),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    RuntimeInstallRef install,
  ) async {
    final RuntimeBloc bloc = context.read<RuntimeBloc>();
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        key: const ValueKey('runtime-remove-dialog'),
        title: Text(l10n.runtimeRemoveTitle(install.id)),
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
      bloc.add(RuntimeRemoveRequested(install.tag, install.backend));
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 MiB';
  }
  final double mib = bytes / 1048576;
  if (mib >= 1024) {
    return '${(mib / 1024).toStringAsFixed(2)} GiB';
  }
  return '${mib.toStringAsFixed(1)} MiB';
}
