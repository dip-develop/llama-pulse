import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../app/platform/clipboard_service.dart';
import '../../app/platform/model_path_picker.dart';
import '../../app/platform/server_binary_picker.dart';
import 'bloc/server_bloc.dart';
import 'bloc/server_dashboard_state.dart';
import 'widgets/server_config_form.dart';
import 'widgets/server_endpoint_card.dart';
import 'widgets/server_log_panel.dart';
import 'widgets/server_metrics_panel.dart';
import 'widgets/server_status_card.dart';

/// Primary screen: configure, start and watch the supervised `llama-server`.
///
/// Above 900 px the configuration form sits in its own column so the live
/// panels keep a stable width; below that everything stacks in one scroll.
class ServerDashboardScreen extends StatelessWidget {
  const ServerDashboardScreen({
    super.key,
    required this.picker,
    required this.binaryPicker,
    required this.clipboard,
    this.demoServer = false,
  });

  /// File dialog used by the model path browse button.
  final ModelPathPicker picker;

  /// File dialog used by the binary path browse button.
  final ServerBinaryPicker binaryPicker;

  /// Clipboard seam used by the endpoint copy button.
  final ClipboardService clipboard;

  /// Whether a synthetic controller backs this run; shows a demo banner.
  final bool demoServer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const ValueKey('server-screen'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (demoServer) const _DemoServerBanner(),
          const _ServerFailureBanner(),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth >= 900) {
                  return _wide();
                }
                return _narrow();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _wide() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 380,
            child: SingleChildScrollView(child: _configForm()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _panels(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrow() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_configForm(), const SizedBox(height: 16), ..._panels()],
      ),
    );
  }

  Widget _configForm() {
    return BlocSelector<
      ServerBloc,
      ServerDashboardState,
      (ServerConfig, bool, bool)
    >(
      selector: (ServerDashboardState state) =>
          (state.config, state.dirty, state.saving),
      builder: (BuildContext context, (ServerConfig, bool, bool) data) {
        final (ServerConfig config, bool dirty, bool saving) = data;
        return ServerConfigForm(
          config: config,
          dirty: dirty,
          saving: saving,
          picker: picker,
          binaryPicker: binaryPicker,
        );
      },
    );
  }

  List<Widget> _panels() {
    return [
      const ServerStatusCard(),
      const SizedBox(height: 16),
      ServerEndpointCard(clipboard: clipboard),
      const SizedBox(height: 16),
      const ServerMetricsPanel(),
      const SizedBox(height: 16),
      const SizedBox(height: 320, child: ServerLogPanel()),
    ];
  }
}

class _DemoServerBanner extends StatelessWidget {
  const _DemoServerBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: const ValueKey('demo-server-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.tertiaryContainer,
      child: Text(
        'Demo server — no llama-server process is started.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}

class _ServerFailureBanner extends StatelessWidget {
  const _ServerFailureBanner();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ServerBloc, ServerDashboardState, ServerFailure?>(
      selector: (ServerDashboardState state) => state.failure,
      builder: (BuildContext context, ServerFailure? failure) {
        if (failure == null) {
          return const SizedBox.shrink();
        }
        final ThemeData theme = Theme.of(context);
        final String? details = failure.details;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            key: const ValueKey('server-failure-banner'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 20,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${failure.code.name}: ${failure.message}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      if (details != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            details,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
