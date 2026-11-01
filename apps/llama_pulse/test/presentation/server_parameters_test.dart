import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/presentation/server/bloc/server_bloc.dart';
import 'package:llama_pulse/presentation/server/bloc/server_event.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../support/fake_file_picker.dart';
import '../support/fake_server_controller.dart';
import '../support/pump_app.dart';

const List<String> _groupIds = <String>[
  'essentials',
  'memory',
  'threads',
  'gpu',
  'batching',
  'sampling',
  'grammar',
  'lora',
  'server',
  'logging',
  'managed',
  'unsupported',
];

void main() {
  testWidgets('sits under the essentials form in the left column', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(const ValueKey('server-params-panel')), findsOneWidget);
    expect(find.text('Server parameters'), findsOneWidget);
    expect(find.text('0 modified / 210 available'), findsOneWidget);
    expect(
      _left(tester, 'server-params-panel'),
      moreOrLessEquals(_left(tester, 'server-config-card')),
    );
    expect(
      _top(tester, 'server-params-panel'),
      greaterThan(_top(tester, 'server-config-card')),
    );
    expect(
      _left(tester, 'server-params-panel'),
      lessThan(_left(tester, 'server-status-card')),
    );
  });

  testWidgets('renders every group in catalog order and opens the defaults', (
    tester,
  ) async {
    await _pump(tester);

    for (final String id in _groupIds) {
      expect(
        find.byKey(ValueKey('server-param-group-$id-toggle')),
        findsOneWidget,
        reason: id,
      );
    }
    double previous = double.negativeInfinity;
    for (final String id in _groupIds) {
      final double top = _top(tester, 'server-param-group-$id-toggle');
      expect(top, greaterThan(previous), reason: id);
      previous = top;
    }
    expect(find.text('Model & context'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);

    // The catalog opens essentials and sampling, and nothing else.
    expect(find.byKey(const ValueKey('server-param-keep')), findsOneWidget);
    expect(find.byKey(const ValueKey('server-param-seed')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('server-param-override-kv')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('server-param-help')), findsNothing);
  });

  testWidgets('a search narrows the groups and clearing restores them', (
    tester,
  ) async {
    await _pump(tester);

    await _search(tester, 'cpu-mask');
    expect(
      find.byKey(const ValueKey('server-param-group-threads-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('server-param-group-essentials-toggle')),
      findsNothing,
    );
    // A group that is closed by default opens while it has hits.
    expect(find.byKey(const ValueKey('server-param-cpu-mask')), findsOneWidget);

    await _search(tester, 'TOP-K');
    expect(find.byKey(const ValueKey('server-param-top-k')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('server-param-group-sampling-toggle')),
      findsOneWidget,
    );

    await _search(tester, '');
    expect(find.byKey(const ValueKey('server-param-cpu-mask')), findsNothing);
    expect(find.byKey(const ValueKey('server-param-keep')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('server-param-group-memory-toggle')),
      findsOneWidget,
    );

    await _search(tester, 'no-such-parameter');
    expect(find.text('No parameters match'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('server-param-group-essentials-toggle')),
      findsNothing,
    );
  });

  testWidgets('modified only filters the rows and the count follows edits', (
    tester,
  ) async {
    await _pump(tester);
    expect(_count(tester), '0 modified / 210 available');

    await _dispatch(tester, const ServerParamChanged('temp', '0.5'));
    expect(_count(tester), '1 modified / 210 available');

    await _tapKey(tester, 'server-params-modified-only');
    expect(find.byKey(const ValueKey('server-param-temp')), findsOneWidget);
    expect(find.byKey(const ValueKey('server-param-seed')), findsNothing);
    expect(
      find.byKey(const ValueKey('server-param-group-sampling-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('server-param-group-threads-toggle')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('server-param-group-managed-toggle')),
      findsNothing,
      reason: 'locked containers hold no user edits',
    );

    await _tapKey(tester, 'server-params-modified-only');
    expect(find.byKey(const ValueKey('server-param-seed')), findsOneWidget);
  });

  testWidgets('renders the control that matches the value type', (
    tester,
  ) async {
    await _pump(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('server-param-kv-unified')),
        matching: find.byType(Switch),
      ),
      findsOneWidget,
      reason: 'a boolean is a switch',
    );
    expect(
      _field(tester, 'server-param-keep-control').keyboardType,
      TextInputType.number,
      reason: 'an integer uses the numeric keyboard',
    );

    await _search(tester, 'pooling');
    expect(
      tester.widget(find.byKey(const ValueKey('server-param-pooling-control'))),
      isA<DropdownButton<String>>(),
      reason: 'an enumeration is a dropdown',
    );

    await _search(tester, 'log-file');
    expect(
      find.byKey(const ValueKey('server-param-log-file-browse')),
      findsOneWidget,
      reason: 'a path offers the file dialog',
    );
    expect(
      _field(tester, 'server-param-log-file-control').maxLines,
      1,
      reason: 'a single path is one line',
    );

    await _search(tester, 'override-kv');
    expect(
      _field(tester, 'server-param-override-kv-control').maxLines,
      greaterThan(1),
      reason: 'a repeatable value is multiline',
    );

    await _search(tester, 'cpu-mask');
    expect(find.byKey(const ValueKey('server-param-cpu-mask')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('server-param-cpu-mask-browse')),
      findsNothing,
      reason: 'a plain text value has no Browse button',
    );
  });

  testWidgets('the tooltip carries the flags, the default and the env var', (
    tester,
  ) async {
    await _pump(tester);
    await _search(tester, 'temp');

    final Tooltip tooltip = tester.widget<Tooltip>(
      find.byKey(const ValueKey('server-param-temp-tooltip')),
    );
    final String message = tooltip.message ?? '';
    expect(message, contains('--temp'));
    expect(message, contains('--temperature'));
    expect(message, contains('Sampling temperature.'));
    expect(message, contains('Type: number'));
    expect(message, contains('Default: 0.8'));
    expect(message, contains('Range: 0..2'));
    expect(message, contains('LLAMA_ARG_TEMPERATURE'));
  });

  testWidgets('an edit dispatches the canonical value', (tester) async {
    await _pump(tester);

    await _enter(tester, 'server-param-temp-control', '0.80');

    expect(_bloc(tester).state.config.params['temp'], '0.8');
    expect(_bloc(tester).state.dirty, isTrue);
    expect(find.byKey(const ValueKey('server-param-temp-error')), findsNothing);
  });

  testWidgets('invalid text stays local and leaves the config alone', (
    tester,
  ) async {
    await _pump(tester);

    await _enter(tester, 'server-param-keep-control', 'many');

    expect(
      find.byKey(const ValueKey('server-param-keep-error')),
      findsOneWidget,
    );
    expect(find.textContaining('must be an integer'), findsOneWidget);
    expect(_bloc(tester).state.config.params.containsKey('keep'), isFalse);
    expect(_bloc(tester).state.dirty, isFalse);
  });

  testWidgets('clearing a field removes the parameter', (tester) async {
    await _pump(tester);
    await _dispatch(tester, const ServerParamChanged('keep', '128'));
    expect(_bloc(tester).state.config.params['keep'], '128');

    await _enter(tester, 'server-param-keep-control', '');

    expect(_bloc(tester).state.config.params.containsKey('keep'), isFalse);
    expect(find.byKey(const ValueKey('server-param-keep-error')), findsNothing);
  });

  testWidgets('resetting a row removes the value and offers undo', (
    tester,
  ) async {
    await _pump(tester);
    await _dispatch(tester, const ServerParamChanged('keep', '128'));

    await _tapKey(tester, 'server-param-keep-reset');

    expect(_bloc(tester).state.config.params.containsKey('keep'), isFalse);
    expect(find.text('Undo'), findsOneWidget);
    await _flushSnackBar(tester);
  });

  testWidgets('resetting a group removes every modified value in it', (
    tester,
  ) async {
    await _pump(tester);
    await _dispatch(tester, const ServerParamChanged('temp', '0.5'));
    await _dispatch(tester, const ServerParamChanged('top-k', '20'));
    await _dispatch(tester, const ServerParamChanged('keep', '16'));
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('server-param-group-sampling-modified')),
          )
          .data,
      '2',
    );

    await _tapKey(tester, 'server-param-group-sampling-reset');

    final BuiltMap<String, String> params = _bloc(tester).state.config.params;
    expect(params.containsKey('temp'), isFalse);
    expect(params.containsKey('top-k'), isFalse);
    expect(
      params['keep'],
      '16',
      reason: 'only the group that was reset loses its values',
    );
    expect(find.text('Undo'), findsOneWidget);
    await _flushSnackBar(tester);
  });

  testWidgets('opens the group of a value modified from the outside', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('server-param-override-kv')),
      findsNothing,
    );

    await _dispatch(tester, const ServerParamChanged('override-kv', 'a=int:1'));

    expect(
      find.byKey(const ValueKey('server-param-override-kv')),
      findsOneWidget,
      reason: 'a group holding a modification opens on its own',
    );
  });

  testWidgets('managed parameters are locked and show the effective value', (
    tester,
  ) async {
    await _pump(tester);

    await _search(tester, 'managed by llamapulse');

    expect(find.byKey(const ValueKey('server-param-ctx-size')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('server-param-ctx-size-locked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('server-param-ctx-size-control')),
      findsNothing,
    );
    expect(
      find.text('LlamaPulse always passes the configured context size.'),
      findsOneWidget,
    );
    expect(find.text('Effective value: 4096'), findsOneWidget);
  });

  testWidgets('the API key is masked in the managed group', (tester) async {
    await _pump(tester);
    await _enter(tester, 'server-api-key', 'super-secret');
    await _search(tester, 'managed by llamapulse');

    expect(find.text('Effective value: ••••••'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('server-params-panel')),
        matching: find.text('super-secret'),
      ),
      findsNothing,
    );
  });

  testWidgets('unsupported parameters are locked with their reason', (
    tester,
  ) async {
    await _pump(tester);

    await _search(tester, 'help');

    final ParameterSpec help = ParameterCatalog.v080.byId('help')!;
    expect(find.byKey(const ValueKey('server-param-help')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('server-param-help-locked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('server-param-help-control')),
      findsNothing,
    );
    expect(find.text(help.reason!), findsOneWidget);
  });

  testWidgets('browse fills a path parameter through the file picker', (
    tester,
  ) async {
    final FakeFilePicker picker = FakeFilePicker(path: '/tmp/grammar.gbnf');
    await _pump(tester, filePicker: picker);
    await _search(tester, 'grammar-file');

    await _tapKey(tester, 'server-param-grammar-file-browse');

    expect(picker.calls, 1);
    expect(picker.dialogTitles.single, 'Select Grammar file');
    expect(
      _bloc(tester).state.config.params['grammar-file'],
      '/tmp/grammar.gbnf',
    );
    expect(
      _controlText(tester, 'server-param-grammar-file-control'),
      '/tmp/grammar.gbnf',
    );
  });

  testWidgets('renders the whole catalog expanded at 900x900', (tester) async {
    await _pump(tester, size: const Size(900, 900));

    await _tapKey(tester, 'server-params-expand-all');
    expect(tester.takeException(), isNull);
    for (final String id in _groupIds) {
      expect(
        find.byKey(ValueKey('server-param-group-$id-rows')),
        findsOneWidget,
        reason: id,
      );
    }
    expect(find.byKey(const ValueKey('server-param-help')), findsOneWidget);
    expect(find.byKey(const ValueKey('server-param-model')), findsOneWidget);

    await _tapKey(tester, 'server-params-collapse-all');
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('server-param-help')), findsNothing);
  });

  testWidgets('metrics samples do not rebuild the panel', (tester) async {
    final FakeServerController controller = FakeServerController();
    await _pump(tester, controller: controller);
    final List<String> rebuilt = <String>[];
    debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
      rebuilt.add(element.widget.runtimeType.toString());
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    controller.emitMetrics(ServerMetrics.empty(1));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('server-metric-tokens-per-second')),
      findsOneWidget,
      reason: 'the metrics panel did rebuild',
    );
    expect(rebuilt, isNotEmpty);
    expect(
      rebuilt.where((String name) => name.contains('ParameterRow')),
      isEmpty,
    );
    expect(
      rebuilt.where((String name) => name.contains('ParameterGroupTile')),
      isEmpty,
    );
    expect(
      rebuilt.where((String name) => name.contains('ServerParameter')),
      isEmpty,
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1400, 1200),
  FakeServerController? controller,
  FakeFilePicker? filePicker,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpLlamaPulse(
    tester,
    serverController: controller ?? FakeServerController(),
    filePicker: filePicker ?? FakeFilePicker(),
  );
}

ServerBloc _bloc(WidgetTester tester) => BlocProvider.of<ServerBloc>(
  tester.element(find.byKey(const ValueKey('server-screen'))),
);

Future<void> _dispatch(WidgetTester tester, ServerEvent event) async {
  _bloc(tester).add(event);
  await tester.pump();
  await tester.pump();
}

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
  await tester.pump();
}

Future<void> _search(WidgetTester tester, String query) async {
  await _enter(tester, 'server-params-search', query);
}

/// Lets a SnackBar expire so no timer outlives the test.
Future<void> _flushSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 1));
}

String? _count(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('server-params-count'))).data;

TextField _field(WidgetTester tester, String key) => tester.widget<TextField>(
  find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  ),
);

String _controlText(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

double _left(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dx;

double _top(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dy;
