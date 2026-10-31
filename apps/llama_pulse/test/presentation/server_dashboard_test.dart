import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/app/di/injection.dart';
import 'package:llama_pulse/presentation/server/bloc/server_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../support/fake_clipboard_service.dart';
import '../support/fake_model_path_picker.dart';
import '../support/fake_server_binary_picker.dart';
import '../support/fake_server_controller.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('renders the dashboard as the default tab', (tester) async {
    await pumpLlamaPulse(tester, serverController: FakeServerController());

    expect(find.text('LlamaPulse — Server'), findsOneWidget);
    expect(find.byKey(const ValueKey('server-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('server-config-card')), findsOneWidget);
    for (final String key in <String>[
      'server-model-path',
      'server-model-browse',
      'server-binary-path',
      'server-binary-browse',
      'server-host',
      'server-port',
      'server-context-size',
      'server-threads',
      'server-gpu-layers',
      'server-parallel-slots',
      'server-alias',
      'server-api-key',
      'server-api-key-reveal',
      'server-flash-attn',
      'server-mlock',
      'server-mmap',
      'server-extra-args',
      'server-startup-timeout',
      'server-save',
      'server-reload',
      'server-status-card',
      'server-status-chip',
      'server-start',
      'server-stop',
      'server-endpoint',
      'server-copy-endpoint',
      'server-test-connection',
      'server-metrics-card',
      'server-log-panel',
      'server-clear-logs',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.byKey(const ValueKey('server-failure-banner')), findsNothing);
    expect(find.byKey(const ValueKey('demo-server-banner')), findsNothing);
    expect(find.textContaining('Stopped'), findsOneWidget);
    expect(
      find.text('Metrics appear once the server is running.'),
      findsOneWidget,
    );
    expect(find.text('No log lines yet.'), findsOneWidget);
    expect(find.text('http://127.0.0.1:8080/v1'), findsOneWidget);
  });

  testWidgets('starts and stops through the controller', (tester) async {
    final FakeServerController controller = FakeServerController();
    await pumpLlamaPulse(tester, serverController: controller);

    expect(_enabled(tester, 'server-start'), isTrue);
    expect(_enabled(tester, 'server-stop'), isFalse);

    // A start without a model is rejected by the bloc before it reaches the
    // controller, so give the form a usable path first.
    await _enter(tester, 'server-model-path', '/models/model.gguf');
    await _tapKey(tester, 'server-start');
    expect(controller.startedConfigs, hasLength(1));
    expect(controller.startedConfigs.single.modelPath, '/models/model.gguf');

    controller.emitState(_state(ServerPhase.running));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Running'), findsOneWidget);
    expect(_enabled(tester, 'server-start'), isFalse);
    expect(_enabled(tester, 'server-stop'), isTrue);

    await _tapKey(tester, 'server-stop');
    expect(controller.stopCalls, 1);
  });

  testWidgets('marks the form dirty and persists edits', (tester) async {
    await pumpLlamaPulse(tester, serverController: FakeServerController());

    await _enter(tester, 'server-context-size', '8192');
    expect(find.text('Unsaved changes'), findsOneWidget);

    await _tapKey(tester, 'server-save');

    final ServerConfig saved = await getIt<ServerConfigRepository>().load();
    expect(saved.contextSize, 8192);
    expect(find.text('Unsaved changes'), findsNothing);
  });

  testWidgets('rejects an invalid port without writing', (tester) async {
    await pumpLlamaPulse(tester, serverController: FakeServerController());

    await _enter(tester, 'server-port', '70000');
    await _tapKey(tester, 'server-save');

    expect(find.byKey(const ValueKey('server-failure-banner')), findsOneWidget);
    expect(find.textContaining('port must be in'), findsOneWidget);

    final ServerConfig stored = await getIt<ServerConfigRepository>().load();
    expect(stored.port, 8080);
  });

  testWidgets('browse fills the model and binary paths', (tester) async {
    final FakeModelPathPicker picker = FakeModelPathPicker(
      path: '/models/picked.gguf',
    );
    final FakeServerBinaryPicker binaryPicker = FakeServerBinaryPicker(
      path: '/opt/picked-server',
    );
    await pumpLlamaPulse(
      tester,
      serverController: FakeServerController(),
      picker: picker,
      binaryPicker: binaryPicker,
    );

    await _tapKey(tester, 'server-model-browse');
    expect(picker.calls, 1);
    expect(_fieldText(tester, 'server-model-path'), '/models/picked.gguf');

    await _tapKey(tester, 'server-binary-browse');
    expect(binaryPicker.calls, 1);
    expect(_fieldText(tester, 'server-binary-path'), '/opt/picked-server');
  });

  testWidgets('toggles the API key visibility', (tester) async {
    _useView(tester, const Size(1000, 1600));
    await pumpLlamaPulse(tester, serverController: FakeServerController());

    await _enter(tester, 'server-api-key', 'secret-token');
    expect(_obscured(tester, 'server-api-key'), isTrue);

    await _tapKey(tester, 'server-api-key-reveal');
    expect(_obscured(tester, 'server-api-key'), isFalse);
  });

  testWidgets('maps extra arguments one per line', (tester) async {
    await pumpLlamaPulse(tester, serverController: FakeServerController());

    await _enter(
      tester,
      'server-extra-args',
      '  --verbose  \n\n  --cont-batching  \n',
    );
    await _tapKey(tester, 'server-save');

    final ServerConfig saved = await getIt<ServerConfigRepository>().load();
    expect(saved.extraArgs, <String>['--verbose', '--cont-batching']);
  });

  testWidgets('copies the endpoint through the clipboard seam', (tester) async {
    final FakeClipboardService clipboard = FakeClipboardService();
    await pumpLlamaPulse(
      tester,
      serverController: FakeServerController(),
      clipboard: clipboard,
    );

    await _tapKey(tester, 'server-copy-endpoint');

    expect(clipboard.calls, 1);
    expect(clipboard.lastText, 'http://127.0.0.1:8080/v1');
  });

  testWidgets('reports latency and an unauthorized probe', (tester) async {
    final FakeServerController controller = FakeServerController(
      probeResult: const ServerProbeResult(
        ok: false,
        latencyMs: 12,
        message: 'unauthorized',
      ),
    );
    await pumpLlamaPulse(tester, serverController: controller);

    await _tapKey(tester, 'server-test-connection');

    expect(controller.probedConfigs, hasLength(1));
    expect(
      find.byKey(const ValueKey('server-connection-result')),
      findsOneWidget,
    );
    expect(find.textContaining('12 ms'), findsOneWidget);
    expect(find.textContaining('unauthorized'), findsOneWidget);
  });

  testWidgets('follows metrics and logs from the fake streams', (tester) async {
    final FakeServerController controller = FakeServerController();
    await pumpLlamaPulse(tester, serverController: controller);
    final ServerBloc bloc = BlocProvider.of<ServerBloc>(
      tester.element(find.byKey(const ValueKey('server-screen'))),
    );

    controller.emitMetrics(
      _metrics(tokensPerSecond: 42.5, contextUsageRatio: 0.25),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('42.5 tok/s'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    for (final String key in <String>[
      'server-metric-tokens-per-second',
      'server-metric-prompt-tokens-per-second',
      'server-metric-active-slots',
      'server-metric-context-usage',
      'server-metric-requests',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('server-metric-context-usage')),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsOneWidget,
    );

    controller.emitMetrics(_metrics(tokensPerSecond: 7.5));
    await tester.pump();
    await tester.pump();

    expect(find.text('7.5 tok/s'), findsOneWidget);
    expect(find.text('not exposed'), findsOneWidget);

    controller.emitLog(_log(1, 'line one'));
    controller.emitLog(_log(2, 'line two'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('line one'), findsOneWidget);
    expect(find.textContaining('line two'), findsOneWidget);

    await _tapKey(tester, 'server-clear-logs');
    expect(find.text('No log lines yet.'), findsOneWidget);
    expect(bloc.state.logs, isEmpty);
  });

  testWidgets('caps the metrics history at the panel boundary', (tester) async {
    final FakeServerController controller = FakeServerController();
    await pumpLlamaPulse(tester, serverController: controller);
    final ServerBloc bloc = BlocProvider.of<ServerBloc>(
      tester.element(find.byKey(const ValueKey('server-screen'))),
    );

    for (var i = 1; i <= ServerBloc.maxMetricsHistory + 5; i++) {
      controller.emitMetrics(_metrics(tokensPerSecond: i.toDouble()));
    }
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(bloc.state.metricsHistory, hasLength(ServerBloc.maxMetricsHistory));
    expect(
      find.text('${ServerBloc.maxMetricsHistory + 5}.0 tok/s'),
      findsOneWidget,
    );
  });

  testWidgets('shows the demo banner for a stub server', (tester) async {
    await pumpLlamaPulse(
      tester,
      serverController: FakeServerController(),
      demoServer: true,
    );

    expect(find.byKey(const ValueKey('demo-server-banner')), findsOneWidget);
    expect(
      find.text('Demo server — no llama-server process is started.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the stored flash attention mode after Reload', (
    tester,
  ) async {
    await pumpLlamaPulse(tester, serverController: FakeServerController());

    expect(find.text('auto'), findsOneWidget);

    await getIt<ServerConfigRepository>().save(
      ServerConfig.defaults().copyWith(
        flashAttention: ServerFlashAttention.off,
      ),
    );
    await _tapKey(tester, 'server-reload');

    expect(find.text('off'), findsOneWidget);
    expect(find.text('auto'), findsNothing);
  });

  testWidgets('renders the warning of a supported binary', (tester) async {
    final FakeServerController controller = FakeServerController(
      binaryInfo: ServerBinaryInfo(
        (b) => b
          ..path = '/opt/llama-server'
          ..version = '0.9.0'
          ..supported = true
          ..warning = 'build 9999 renamed a flag; it may be ignored'
          ..rawOutput = 'llama-server 0.9.0',
      ),
    );
    await pumpLlamaPulse(tester, serverController: controller);

    expect(find.byKey(const ValueKey('server-binary-warning')), findsOneWidget);
    expect(find.textContaining('build 9999'), findsOneWidget);
  });

  testWidgets('flags a server started outside the app', (tester) async {
    final ServerState recorded = _state(ServerPhase.running).rebuild(
      (b) => b
        ..supervisorPid = 4242
        ..serverPid = 4243
        ..startedAtEpochMs = 1,
    );
    await pumpLlamaPulse(
      tester,
      serverController: FakeServerController(),
      recordedState: recorded,
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('server-external-run')), findsOneWidget);
    expect(find.textContaining('llamapulse stop'), findsOneWidget);
    expect(_enabled(tester, 'server-start'), isFalse);
    expect(find.textContaining('Running'), findsOneWidget);
  });

  testWidgets('puts the configuration beside the panels on wide windows', (
    tester,
  ) async {
    _useView(tester, const Size(1400, 1000));
    await pumpLlamaPulse(tester, serverController: FakeServerController());

    expect(
      _left(tester, 'server-config-card'),
      lessThan(_left(tester, 'server-status-card')),
    );
    expect(
      _top(tester, 'server-config-card'),
      moreOrLessEquals(_top(tester, 'server-status-card')),
    );
    expect(find.byKey(const ValueKey('chat-tab')), findsOneWidget);
  });

  testWidgets('stacks the configuration above the panels on narrow windows', (
    tester,
  ) async {
    _useView(tester, const Size(700, 1200));
    await pumpLlamaPulse(tester, serverController: FakeServerController());

    expect(
      _top(tester, 'server-status-card'),
      greaterThan(_top(tester, 'server-config-card')),
    );
    expect(find.byKey(const ValueKey('server-log-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-tab')), findsOneWidget);
  });
}

ServerState _state(ServerPhase phase) => ServerState(
  (b) => b
    ..phase = phase
    ..health = ServerHealth.ok
    ..host = '127.0.0.1'
    ..port = 8080
    ..modelPath = '/models/model.gguf'
    ..binaryPath = '/opt/llama-server'
    ..updatedAtEpochMs = 0,
);

ServerMetrics _metrics({
  double tokensPerSecond = 12.5,
  double promptTokensPerSecond = 99.5,
  int activeSlots = 1,
  int totalSlots = 4,
  int requestsProcessing = 1,
  int requestsDeferred = 2,
  int tokensPredictedTotal = 42,
  int? uptimeSeconds = 90,
  double? contextUsageRatio,
}) => ServerMetrics.empty(0).rebuild(
  (b) => b
    ..tokensPerSecond = tokensPerSecond
    ..promptTokensPerSecond = promptTokensPerSecond
    ..activeSlots = activeSlots
    ..totalSlots = totalSlots
    ..requestsProcessing = requestsProcessing
    ..requestsDeferred = requestsDeferred
    ..tokensPredictedTotal = tokensPredictedTotal
    ..uptimeSeconds = uptimeSeconds
    ..contextUsageRatio = contextUsageRatio,
);

ServerLogEntry _log(int sequence, String line) => ServerLogEntry(
  (b) => b
    ..sequence = sequence
    ..timestampEpochMs = sequence
    ..stream = ServerLogStream.supervisor
    ..line = line,
);

Future<void> _tapKey(WidgetTester tester, String key) async {
  final Finder finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final Finder finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.enterText(finder, text);
  await tester.pump();
}

bool _enabled(WidgetTester tester, String key) {
  final Widget widget = tester.widget(find.byKey(ValueKey(key)));
  return switch (widget) {
    final ButtonStyleButton button => button.onPressed != null,
    _ => throw StateError('$key is not a button'),
  };
}

bool _obscured(WidgetTester tester, String key) {
  final EditableText editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(EditableText),
    ),
  );
  return editable.obscureText;
}

String _fieldText(WidgetTester tester, String key) {
  final EditableText editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(EditableText),
    ),
  );
  return editable.controller.text;
}

void _useView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

double _left(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dx;

double _top(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dy;
