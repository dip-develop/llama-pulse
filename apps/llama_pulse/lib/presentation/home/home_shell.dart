import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/di/injection.dart';
import '../../app/platform/clipboard_service.dart';
import '../../app/platform/file_picker.dart';
import '../../app/platform/model_path_picker.dart';
import '../../app/platform/server_binary_picker.dart';
import '../../l10n/app_localizations.dart';
import '../inference/bloc/inference_bloc.dart';
import '../inference/bloc/inference_event.dart';
import '../inference/chat_screen.dart';
import '../runtime/bloc/runtime_bloc.dart';
import '../runtime/bloc/runtime_event.dart';
import '../runtime/runtime_screen.dart';
import '../server/bloc/server_bloc.dart';
import '../server/bloc/server_event.dart';
import '../server/server_dashboard_screen.dart';

/// Window shell: the only [Scaffold] in the app, a destination rail and the
/// two long-lived screens.
///
/// Both blocs are created here, above the tab switch, so their state (dirty
/// configuration, prompt, generation output) survives moving between tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.picker,
    required this.binaryPicker,
    required this.filePicker,
    required this.clipboard,
    this.demoServer = false,
    this.demoEngine = false,
  });

  /// File dialog used by the model path fields.
  final ModelPathPicker picker;

  /// File dialog used by the server binary field.
  final ServerBinaryPicker binaryPicker;

  /// File dialog used by the server parameter panel.
  final FilePicker filePicker;

  /// Clipboard seam used by the endpoint copy button.
  final ClipboardService clipboard;

  /// Whether a synthetic server controller backs this run.
  final bool demoServer;

  /// Whether the synthetic stub engine backs this run.
  final bool demoEngine;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const int _serverTab = 0;
  static const int _chatTab = 1;
  static const int _runtimeTab = 2;

  int _index = _serverTab;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ServerBloc>(
          create: (_) =>
              getIt<ServerBloc>()..add(const ServerDashboardStarted()),
        ),
        BlocProvider<InferenceBloc>(
          create: (_) => getIt<InferenceBloc>()..add(const InferenceStarted()),
        ),
        BlocProvider<RuntimeBloc>(
          create: (_) => getIt<RuntimeBloc>()..add(const RuntimeStarted()),
        ),
      ],
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 900;
          final AppLocalizations l10n = AppLocalizations.of(context)!;
          return Scaffold(
            appBar: AppBar(title: Text(_title(l10n))),
            body: wide
                ? Row(
                    children: [
                      _rail(l10n),
                      const VerticalDivider(width: 1),
                      Expanded(child: _body()),
                    ],
                  )
                : _body(),
            bottomNavigationBar: wide ? null : _bar(l10n),
          );
        },
      ),
    );
  }

  String _title(AppLocalizations l10n) => switch (_index) {
    _chatTab => l10n.homeTitleChat,
    _runtimeTab => l10n.homeTitleRuntime,
    _ => l10n.homeTitleServer,
  };

  Widget _body() {
    return IndexedStack(
      index: _index,
      children: [
        ServerDashboardScreen(
          picker: widget.picker,
          binaryPicker: widget.binaryPicker,
          filePicker: widget.filePicker,
          clipboard: widget.clipboard,
          demoServer: widget.demoServer,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ExperimentalBanner(),
            Expanded(
              child: ChatScreen(
                picker: widget.picker,
                filePicker: widget.filePicker,
                demoEngine: widget.demoEngine,
              ),
            ),
          ],
        ),
        const RuntimeScreen(),
      ],
    );
  }

  Widget _rail(AppLocalizations l10n) {
    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: _select,
      labelType: NavigationRailLabelType.all,
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.dns_outlined),
          selectedIcon: const Icon(Icons.dns),
          label: Text(l10n.navServer, key: const ValueKey('server-tab')),
        ),
        NavigationRailDestination(
          icon: Tooltip(
            message: l10n.navChatExperimental,
            child: const Icon(Icons.chat_bubble_outline),
          ),
          selectedIcon: const Icon(Icons.chat_bubble),
          label: Text(l10n.navChat, key: const ValueKey('chat-tab')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.memory_outlined),
          selectedIcon: const Icon(Icons.memory),
          label: Text(l10n.navRuntime, key: const ValueKey('runtime-tab')),
        ),
      ],
    );
  }

  Widget _bar(AppLocalizations l10n) {
    return NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: _select,
      destinations: [
        NavigationDestination(
          key: const ValueKey('server-tab'),
          icon: const Icon(Icons.dns_outlined),
          selectedIcon: const Icon(Icons.dns),
          label: l10n.navServer,
        ),
        NavigationDestination(
          key: const ValueKey('chat-tab'),
          icon: const Icon(Icons.chat_bubble_outline),
          selectedIcon: const Icon(Icons.chat_bubble),
          label: l10n.navChatExperimental,
        ),
        NavigationDestination(
          key: const ValueKey('runtime-tab'),
          icon: const Icon(Icons.memory_outlined),
          selectedIcon: const Icon(Icons.memory),
          label: l10n.navRuntime,
        ),
      ],
    );
  }
}

class _ExperimentalBanner extends StatelessWidget {
  const _ExperimentalBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      key: const ValueKey('chat-experimental-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.secondaryContainer,
      child: Text(
        l10n.chatExperimentalBanner,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
