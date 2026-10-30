import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/di/injection.dart';
import '../../app/platform/clipboard_service.dart';
import '../../app/platform/model_path_picker.dart';
import '../../app/platform/server_binary_picker.dart';
import '../inference/bloc/inference_bloc.dart';
import '../inference/bloc/inference_event.dart';
import '../inference/chat_screen.dart';
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
    required this.clipboard,
    this.demoServer = false,
    this.demoEngine = false,
  });

  /// File dialog used by the model path fields.
  final ModelPathPicker picker;

  /// File dialog used by the server binary field.
  final ServerBinaryPicker binaryPicker;

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
      ],
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 900;
          return Scaffold(
            appBar: AppBar(title: Text(_title)),
            body: wide
                ? Row(
                    children: [
                      _rail(),
                      const VerticalDivider(width: 1),
                      Expanded(child: _body()),
                    ],
                  )
                : _body(),
            bottomNavigationBar: wide ? null : _bar(),
          );
        },
      ),
    );
  }

  String get _title =>
      _index == _chatTab ? 'LlamaPulse — Chat' : 'LlamaPulse — Server';

  Widget _body() {
    return IndexedStack(
      index: _index,
      children: [
        ServerDashboardScreen(
          picker: widget.picker,
          binaryPicker: widget.binaryPicker,
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
                demoEngine: widget.demoEngine,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rail() {
    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: _select,
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dns_outlined),
          selectedIcon: Icon(Icons.dns),
          label: Text('Server', key: ValueKey('server-tab')),
        ),
        NavigationRailDestination(
          icon: Tooltip(
            message: 'Chat (experimental)',
            child: Icon(Icons.chat_bubble_outline),
          ),
          selectedIcon: Icon(Icons.chat_bubble),
          label: Text('Chat', key: ValueKey('chat-tab')),
        ),
      ],
    );
  }

  Widget _bar() {
    return NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: _select,
      destinations: const [
        NavigationDestination(
          key: ValueKey('server-tab'),
          icon: Icon(Icons.dns_outlined),
          selectedIcon: Icon(Icons.dns),
          label: 'Server',
        ),
        NavigationDestination(
          key: ValueKey('chat-tab'),
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'Chat (experimental)',
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
    return Container(
      key: const ValueKey('chat-experimental-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.secondaryContainer,
      child: Text(
        'Experimental — embedded chat. The server is the primary path.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
