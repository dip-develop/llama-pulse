import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/app/di/injection.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_bloc.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_event.dart';
import 'package:llama_pulse/presentation/inference/widgets/chat_parameters_card.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../support/pump_app.dart';
import '../support/scripted_llama_engine.dart';

void main() {
  testWidgets('renders the editable groups and both locked containers', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(const ValueKey('chat-params-panel')), findsOneWidget);
    expect(find.text('Chat parameters'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-params-count')), findsOneWidget);
    expect(_count(tester), '0 modified / 3 available');
    expect(find.byKey(const ValueKey('chat-params-search')), findsOneWidget);

    for (final String id in <String>[
      'batching',
      'sampling',
      chatManagedGroupId,
      chatServerOnlyGroupId,
    ]) {
      expect(
        find.byKey(ValueKey('chat-param-group-$id-toggle')),
        findsOneWidget,
        reason: id,
      );
    }
    expect(find.text('Batching & cache'), findsOneWidget);
    expect(find.text('Sampling & penalties'), findsOneWidget);
    expect(find.text('Set in the essentials form'), findsOneWidget);
    expect(find.text('Not available in the embedded engine'), findsOneWidget);

    // The catalog opens sampling, and nothing else in the chat panel.
    expect(find.byKey(const ValueKey('chat-param-seed')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-param-min-p')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-param-batch-size')),
      findsNothing,
      reason: 'batching is closed by default',
    );
    expect(
      find.byKey(const ValueKey('chat-param-ctx-size')),
      findsNothing,
      reason: 'the locked essentials container starts collapsed',
    );
    expect(
      find.byKey(const ValueKey('chat-param-cont-batching')),
      findsNothing,
      reason: 'the server-only container starts collapsed',
    );
  });

  testWidgets('embedded rows are editable, owned and server-only rows locked', (
    tester,
  ) async {
    await _pump(tester);

    await _search(tester, 'seed');
    expect(
      find.byKey(const ValueKey('chat-param-seed-control')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('chat-param-seed-locked')), findsNothing);

    await _search(tester, 'batch-size');
    expect(
      find.byKey(const ValueKey('chat-param-batch-size-control')),
      findsOneWidget,
    );

    await _search(tester, 'ctx-size');
    expect(
      find.byKey(const ValueKey('chat-param-ctx-size-locked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-param-ctx-size-control')),
      findsNothing,
      reason: 'the essentials form owns the control',
    );
    expect(
      find.text('Effective value: 2048'),
      findsOneWidget,
      reason: 'the locked row still answers what is set',
    );

    await _search(tester, 'cont-batching');
    expect(
      find.byKey(const ValueKey('chat-param-cont-batching-locked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-param-cont-batching-control')),
      findsNothing,
    );
    expect(find.text(chatServerOnlyReason), findsOneWidget);
  });

  testWidgets('a search narrows the groups and clearing restores them', (
    tester,
  ) async {
    await _pump(tester);

    await _search(tester, 'min-p');
    expect(find.byKey(const ValueKey('chat-param-min-p')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-param-group-batching-toggle')),
      findsNothing,
    );

    await _search(tester, '');
    expect(find.byKey(const ValueKey('chat-param-seed')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-param-group-batching-toggle')),
      findsOneWidget,
    );

    await _search(tester, 'no-such-parameter');
    expect(find.byKey(const ValueKey('chat-params-empty')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-param-group-sampling-toggle')),
      findsNothing,
    );
  });

  testWidgets('modified only filters the rows and hides the locked groups', (
    tester,
  ) async {
    await _pump(tester);

    await _enter(tester, 'chat-param-seed-control', '42');
    expect(_count(tester), '1 modified / 3 available');

    await _tapKey(tester, 'chat-params-modified-only');
    expect(find.byKey(const ValueKey('chat-param-seed')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-param-min-p')), findsNothing);
    expect(
      find.byKey(ValueKey('chat-param-group-$chatManagedGroupId-toggle')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('chat-param-group-$chatServerOnlyGroupId-toggle')),
      findsNothing,
    );

    await _tapKey(tester, 'chat-params-modified-only');
    expect(find.byKey(const ValueKey('chat-param-min-p')), findsOneWidget);
  });

  testWidgets('editing min-p and seed writes the catalog map', (tester) async {
    await _pump(tester);

    await _enter(tester, 'chat-param-min-p-control', '0.10');
    expect(_bloc(tester).state.params.params['min-p'], '0.1');

    await _enter(tester, 'chat-param-seed-control', '42');
    expect(_bloc(tester).state.params.params['seed'], '42');
    expect(
      _bloc(tester).state.params.params.containsKey('ctx-size'),
      isFalse,
      reason: 'typed owners never duplicate the value in the map',
    );
  });

  testWidgets('owned rows follow the typed field edited above', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byKey(const ValueKey('context-size')), '4096');
    await tester.pump();
    await tester.pump();

    await _search(tester, 'chat-template');
    expect(
      find.byKey(const ValueKey('chat-param-chat-template-locked')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-template')),
      'chatml',
    );
    await tester.pump();
    await tester.pump();
    await _search(tester, 'chat-template');

    expect(
      find.byKey(const ValueKey('chat-param-chat-template-effective')),
      findsOneWidget,
    );
    expect(find.text('Effective value: chatml'), findsOneWidget);

    await _search(tester, 'ctx-size');
    expect(find.text('Effective value: 4096'), findsOneWidget);
    expect(_bloc(tester).state.params.params.containsKey('ctx-size'), isFalse);
  });

  testWidgets('the tooltip carries flags, type, default, range and env var', (
    tester,
  ) async {
    await _pump(tester);

    final Tooltip tooltip = tester.widget<Tooltip>(
      find.byKey(const ValueKey('chat-param-min-p-tooltip')),
    );
    final String message = tooltip.message ?? '';
    expect(message, contains('--min-p'));
    expect(message, contains('Minimum probability relative to'));
    expect(message, contains('Type: number'));
    expect(message, contains('Default: 0.05'));
    expect(message, contains('Range: 0..1'));
    expect(message, contains('LLAMA_ARG_MIN_P'));
  });

  testWidgets('resetting a row removes the value and offers undo', (
    tester,
  ) async {
    await _pump(tester);

    await _enter(tester, 'chat-param-seed-control', '42');
    expect(_bloc(tester).state.params.params['seed'], '42');

    await _tapKey(tester, 'chat-param-seed-reset');

    expect(_bloc(tester).state.params.params.containsKey('seed'), isFalse);
    expect(find.text('Undo'), findsOneWidget);
    await _flushSnackBar(tester);
  });

  testWidgets('resetting a group clears every modified map value', (
    tester,
  ) async {
    await _pump(tester);

    await _enter(tester, 'chat-param-min-p-control', '0.1');
    await _enter(tester, 'chat-param-seed-control', '42');
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('chat-param-group-sampling-modified')),
          )
          .data,
      '2',
    );

    await _tapKey(tester, 'chat-param-group-sampling-reset');

    final BuiltMap<String, String> params = _bloc(tester).state.params.params;
    expect(params.containsKey('min-p'), isFalse);
    expect(params.containsKey('seed'), isFalse);
    expect(find.text('Undo'), findsOneWidget);
    await _flushSnackBar(tester);
  });

  testWidgets('an edit stays unsaved until the Save action', (tester) async {
    await _pump(tester);

    await _enter(tester, 'chat-param-min-p-control', '0.1');
    expect((await getIt<LoadModelParams>()()).params['min-p'], isNull);

    await _tapKey(tester, 'save-params');

    expect((await getIt<LoadModelParams>()()).params['min-p'], '0.1');
  });

  testWidgets('a typed event resets a typed field to its default', (
    tester,
  ) async {
    await _pump(tester);
    await _dispatch(tester, const InferenceParamChanged('temp', '0.2'));
    expect(_bloc(tester).state.params.temperature, 0.2);

    await _dispatch(tester, InferenceParamsReset(const {'temp'}));

    expect(_bloc(tester).state.params.temperature, 0.8);
  });

  testWidgets('renders without overflow at 380 px and 900 px', (tester) async {
    for (final double width in <double>[380, 900]) {
      await _pump(tester, size: Size(width, 1400));
      await _tapKey(tester, 'chat-params-expand-all');

      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(
        find.byKey(ValueKey('chat-param-group-$chatServerOnlyGroupId-rows')),
        findsOneWidget,
        reason: 'the server-only container is expanded at $width',
      );
    }
  });

  testWidgets('metrics and tokens do not rebuild the parameter panel', (
    tester,
  ) async {
    final ScriptedLlamaEngine engine = ScriptedLlamaEngine();
    await _pump(tester, engine: engine);
    await _loadAndGenerate(tester, engine);

    final List<String> rebuilt = <String>[];
    debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
      rebuilt.add(element.widget.runtimeType.toString());
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    engine.emitToken('Hello');
    await tester.pump();
    await tester.pump();
    engine.emitMetrics(
      GenerationMetrics(
        (b) => b
          ..promptTokenCount = 3
          ..generatedTokenCount = 20
          ..promptEvalMs = 250
          ..evalMs = 1000,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('20.0 tok/s'), findsOneWidget);
    expect(rebuilt, isNotEmpty);
    for (final String fragment in <String>[
      'ParameterRow',
      'ParameterGroupTile',
      'ParameterPanel',
      'ChatParametersCard',
    ]) {
      expect(
        rebuilt.where((String name) => name.contains(fragment)),
        isEmpty,
        reason: fragment,
      );
    }
  });
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1400, 1200),
  ScriptedLlamaEngine? engine,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpLlamaPulse(tester, engine: engine);
  await tester.tap(find.byKey(const ValueKey('chat-tab')));
  await tester.pump();
  await tester.pump();
}

InferenceBloc _bloc(WidgetTester tester) => BlocProvider.of<InferenceBloc>(
  tester.element(find.byKey(const ValueKey('chat-params-panel'))),
);

Future<void> _dispatch(WidgetTester tester, InferenceEvent event) async {
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
  await _enter(tester, 'chat-params-search', query);
}

Future<void> _loadAndGenerate(
  WidgetTester tester,
  ScriptedLlamaEngine engine,
) async {
  await tester.enterText(
    find.byKey(const ValueKey('model-path')),
    '/models/test.gguf',
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('load-model')));
  await tester.pump();
  await tester.pump();

  await tester.enterText(find.byKey(const ValueKey('prompt-field')), 'Say hi');
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('generate')));
  await tester.pump();
  await tester.pump();

  expect(engine.generatedRequests, hasLength(1));
}

/// Lets a SnackBar expire so no timer outlives the test.
Future<void> _flushSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 1));
}

String? _count(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('chat-params-count'))).data;
