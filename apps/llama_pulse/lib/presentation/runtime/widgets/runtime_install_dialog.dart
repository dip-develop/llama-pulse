import 'package:flutter/material.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../bloc/runtime_bloc.dart';

/// Asks before one backend is downloaded and installed.
///
/// The dialog shows the download size, the CUDA runtime archive when the
/// backend needs one, and the driver floor the host must already meet. It
/// returns true only when the user confirms.
class RuntimeInstallDialog extends StatelessWidget {
  const RuntimeInstallDialog({
    super.key,
    required this.bloc,
    required this.backend,
  });

  /// Bloc that resolves the pinned asset for the detected host.
  final RuntimeBloc bloc;

  /// Backend the user chose.
  final RuntimeBackend backend;

  @override
  Widget build(BuildContext context) {
    final RuntimeAsset? asset = bloc.assetFor(backend);
    final RuntimeAsset? cudart = asset?.cudartAsset;
    final ThemeData theme = Theme.of(context);
    final int total = (asset?.sizeBytes ?? 0) + (cudart?.sizeBytes ?? 0);
    return AlertDialog(
      key: const ValueKey('runtime-install-dialog'),
      title: Text('Install ${backend.displayName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(theme, 'Download', _formatBytes(total)),
          if (cudart != null)
            _line(theme, 'CUDA runtime', _formatBytes(cudart.sizeBytes)),
          _line(theme, 'Platform', asset?.platform.id ?? 'unsupported'),
          const SizedBox(height: 12),
          Text(
            'Driver requirement: ${backend.requires}',
            key: const ValueKey('runtime-install-requires'),
            style: theme.textTheme.bodySmall,
          ),
          if (cudart != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'The CUDA runtime is a second archive bundled only when you '
                'install a CUDA backend.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('runtime-install-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('runtime-install-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Install'),
        ),
      ],
    );
  }

  static Widget _line(ThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  static String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return 'unknown';
    }
    final double mib = bytes / 1048576;
    if (mib >= 1024) {
      return '${(mib / 1024).toStringAsFixed(2)} GiB';
    }
    return '${mib.toStringAsFixed(1)} MiB';
  }
}

/// Opens [RuntimeInstallDialog] for [backend] and reports the answer.
Future<bool> confirmRuntimeInstall(
  BuildContext context, {
  required RuntimeBloc bloc,
  required RuntimeBackend backend,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) =>
        RuntimeInstallDialog(bloc: bloc, backend: backend),
  );
  return confirmed ?? false;
}
