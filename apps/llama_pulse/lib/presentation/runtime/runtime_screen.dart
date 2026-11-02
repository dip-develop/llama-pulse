import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import 'bloc/runtime_bloc.dart';
import 'bloc/runtime_event.dart';
import 'bloc/runtime_state.dart';
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
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _Banner(
                    key: const ValueKey('runtime-tab-error'),
                    message: state.errorMessage!,
                    error: true,
                  ),
                ],
                if (state.noticeMessage != null) ...[
                  const SizedBox(height: 16),
                  _Banner(
                    key: const ValueKey('runtime-tab-notice'),
                    message: state.noticeMessage!,
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
                  child: Text('Runtime', style: theme.textTheme.titleMedium),
                ),
                if (state.loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                IconButton(
                  key: const ValueKey('runtime-refresh'),
                  tooltip: 'Refresh',
                  onPressed: state.busy
                      ? null
                      : () => context.read<RuntimeBloc>().add(
                          const RuntimeRefreshed(),
                        ),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.hardwareSummary ?? 'Detecting the host…',
              key: const ValueKey('runtime-hardware-summary'),
              style: theme.textTheme.bodyMedium,
            ),
            if (state.recommendedBackend != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Recommended: ${state.recommendedBackend!.displayName} — '
                  '${state.recommendationReason ?? ''}',
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
                  'The pinned release has no archive for this host.',
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
    final RuntimeBackend backend = state.installingBackend!;
    return Card(
      key: const ValueKey('runtime-tab-progress'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Installing ${backend.displayName}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: state.progressFraction),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${(state.progressFraction * 100).floor()}% · '
                    '${_formatBytes(state.progressReceived)} of '
                    '${_formatBytes(state.progressTotal)}'
                    '${state.bytesPerSecond <= 0 ? '' : ' · ${_formatBytes(state.bytesPerSecond.round())}/s'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  key: const ValueKey('runtime-tab-cancel'),
                  onPressed: () => context.read<RuntimeBloc>().add(
                    const RuntimeCancelRequested(),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Backends extends StatelessWidget {
  const _Backends({required this.state});

  final RuntimeState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const ValueKey('runtime-backends-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available backends', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            if (state.offeredBackends.isEmpty)
              Text('No backend is available for this host.')
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
                        label: const Text('Recommended'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                    if (installed) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text('Installed'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                Text(
                  supported
                      ? (support?.reason ?? backend.requires)
                      : 'Unavailable: ${support?.reason ?? backend.requires}',
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
            child: Text(installed ? 'Reinstall' : 'Install'),
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
    return Card(
      key: const ValueKey('runtime-installed-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Installed', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            if (state.installed.isEmpty)
              const Text('No runtimes installed yet.')
            else
              for (final install in state.installed)
                _InstalledRow(state: state, install: install),
            if (state.gateVerdict != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Gate: ${state.gateVerdict!.name}'
                  '${state.gateReason == null ? '' : ' — ${state.gateReason}'}',
                  key: const ValueKey('runtime-gate'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: state.gateAccepted
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
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
            child: Text(selected ? 'Selected' : 'Select'),
          ),
          TextButton(
            key: ValueKey('runtime-remove-${install.backend.id}'),
            onPressed: state.busy
                ? null
                : () => _confirmRemove(context, install),
            child: const Text('Remove'),
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
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        key: const ValueKey('runtime-remove-dialog'),
        title: Text('Remove ${install.id}?'),
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
