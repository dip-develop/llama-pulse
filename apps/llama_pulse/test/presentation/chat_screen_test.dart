import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/app/di/injection.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../support/fake_model_path_picker.dart';
import '../support/pump_app.dart';
import '../support/scripted_llama_engine.dart';

void main() {
  testWidgets('renders the workspace with stored defaults', (tester) async {
    await pumpLlamaPulse(tester);

    expect(find.text('LlamaPulse — Server'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-experimental-banner')),
      findsNothing,
    );

    await _openChat(tester);

    expect(find.text('LlamaPulse — Chat'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-experimental-banner')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Experimental — embedded chat. The server is the primary path.',
      ),
      findsOneWidget,
    );
    expect(find.text('Idle'), findsOneWidget);
    expect(_fieldText(tester, 'model-path'), isEmpty);
    expect(_fieldText(tester, 'context-size'), '2048');
    expect(_fieldText(tester, 'gpu-layers'), '0');
    expect(_fieldText(tester, 'threads'), '4');
    expect(_fieldText(tester, 'temperature'), '0.8');
    expect(_fieldText(tester, 'top-p'), '0.95');
    expect(_fieldText(tester, 'top-k'), '40');
    expect(_fieldText(tester, 'max-tokens'), '256');
    expect(_fieldText(tester, 'chat-template'), isEmpty);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('use-chat-template')),
          )
          .value,
      isTrue,
    );
    expect(find.text('No messages yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-conversation')), findsOneWidget);
    expect(_clearEnabled(tester), isFalse);
    expect(
      find.text('Metrics appear here after a generation.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('demo-engine-banner')), findsNothing);
  });

  testWidgets('shows the demo banner when the stub engine is active', (
    tester,
  ) async {
    await pumpLlamaPulse(tester, demoEngine: true);
    await _openChat(tester);

    expect(find.byKey(const ValueKey('demo-engine-banner')), findsOneWidget);
    expect(find.text('Demo engine — output is synthetic.'), findsOneWidget);
  });

  testWidgets('places the cards side by side on wide windows', (tester) async {
    _useView(tester, const Size(1400, 900));
    await pumpLlamaPulse(tester);
    await _openChat(tester);

    expect(_top(tester, 'parameters-card'), _top(tester, 'output-card'));
    expect(
      _top(tester, 'chat-params-panel'),
      greaterThan(_top(tester, 'parameters-card')),
      reason: 'the catalog panel sits under the essentials form',
    );
  });

  testWidgets('stacks the cards on narrow windows', (tester) async {
    _useView(tester, const Size(700, 1200));
    await pumpLlamaPulse(tester);
    await _openChat(tester);

    expect(
      _top(tester, 'output-card'),
      greaterThan(_top(tester, 'parameters-card')),
    );
    expect(
      _top(tester, 'chat-params-panel'),
      greaterThan(_top(tester, 'parameters-card')),
      reason: 'the catalog panel sits under the essentials form',
    );
  });

  testWidgets('browse fills the model path from the picker', (tester) async {
    _useView(tester, const Size(1400, 1000));
    final FakeModelPathPicker picker = FakeModelPathPicker(
      path: '/models/picked.gguf',
    );
    await pumpLlamaPulse(tester, picker: picker);
    await _openChat(tester);

    await tester.tap(find.byKey(const ValueKey('browse-model-path')));
    await tester.pump();

    expect(picker.calls, 1);
    expect(_fieldText(tester, 'model-path'), '/models/picked.gguf');
  });

  testWidgets('saves edited parameters and ignores invalid numbers', (
    tester,
  ) async {
    _useView(tester, const Size(1400, 1000));
    await pumpLlamaPulse(tester);
    await _openChat(tester);

    await tester.enterText(find.byKey(const ValueKey('context-size')), '4096');
    await tester.pump();
    await _saveParams(tester);

    expect((await getIt<LoadModelParams>()()).contextSize, 4096);

    await tester.enterText(find.byKey(const ValueKey('context-size')), 'abc');
    await tester.pump();
    await _saveParams(tester);

    expect((await getIt<LoadModelParams>()()).contextSize, 4096);
  });

  testWidgets('saves the chat-template settings', (tester) async {
    _useView(tester, const Size(1400, 1000));
    await pumpLlamaPulse(tester);
    await _openChat(tester);

    await tester.enterText(
      find.byKey(const ValueKey('chat-template')),
      'chatml',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('use-chat-template')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('use-chat-template')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('save-params')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-params')));
    await tester.pump();
    await tester.pump();

    final ModelParams saved = await getIt<LoadModelParams>()();
    expect(saved.chatTemplate, 'chatml');
    expect(saved.useChatTemplate, isFalse);
  });

  testWidgets('saves the system prompt', (tester) async {
    _useView(tester, const Size(1400, 1000));
    await pumpLlamaPulse(tester);
    await _openChat(tester);

    await _enterSystemPrompt(tester, 'You are terse');
    await _saveParams(tester);

    final ModelParams saved = await getIt<LoadModelParams>()();
    expect(saved.systemPrompt, 'You are terse');
  });

  testWidgets('saves a blank system prompt as null', (tester) async {
    _useView(tester, const Size(1400, 1000));
    await pumpLlamaPulse(tester);
    await _openChat(tester);

    await _enterSystemPrompt(tester, 'You are terse');
    await _saveParams(tester);
    expect((await getIt<LoadModelParams>()()).systemPrompt, 'You are terse');

    await _enterSystemPrompt(tester, '   ');
    await _saveParams(tester);

    expect((await getIt<LoadModelParams>()()).systemPrompt, isNull);
  });

  testWidgets('sends the saved system prompt as the first message', (
    tester,
  ) async {
    _useView(tester, const Size(1400, 1000));
    final ScriptedLlamaEngine engine = ScriptedLlamaEngine();
    await pumpLlamaPulse(tester, engine: engine);
    await _openChat(tester);

    await _enterSystemPrompt(tester, 'You are terse');
    await _saveParams(tester);

    await _loadAndGenerate(tester, engine);

    final ChatMessage first = engine.generatedRequests.single.messages.first;
    expect(first.role, ChatMessage.roleSystem);
    expect(first.content, 'You are terse');
    expect(_turnText(tester, 0), 'Say hi');
    expect(find.byKey(const ValueKey('transcript-text-1')), findsNothing);
  });

  testWidgets('shows the stored system prompt in the field', (tester) async {
    _useView(tester, const Size(1400, 1000));
    await pumpLlamaPulse(
      tester,
      recordedParams: ModelParams.defaults().copyWith(
        systemPrompt: 'Stored prompt',
      ),
    );
    await _openChat(tester);

    expect(_fieldText(tester, 'system-prompt'), 'Stored prompt');
  });

  testWidgets('reports the searched paths when no native library is found', (
    tester,
  ) async {
    _useView(tester, const Size(1400, 1000));
    final ScriptedLlamaEngine engine = ScriptedLlamaEngine()
      ..loadSucceeds = false
      ..loadFailure = LlamaLibraryLocator().notFoundFailure();
    await pumpLlamaPulse(tester, engine: engine);
    await _openChat(tester);

    await tester.enterText(
      find.byKey(const ValueKey('model-path')),
      '/models/missing.gguf',
    );
    await tester.pump();
    await _tapVisible(tester, 'load-model');

    expect(find.byKey(const ValueKey('failure-banner')), findsOneWidget);
    expect(find.textContaining('libraryNotFound'), findsOneWidget);
    final String searched = (engine.loadFailure.details ?? '')
        .split('\n')
        .first;
    expect(searched, isNotEmpty);
    expect(find.textContaining(searched), findsOneWidget);
  });

  testWidgets('loads, streams tokens, shows metrics and completes', (
    tester,
  ) async {
    _useView(tester, const Size(1400, 1000));
    final ScriptedLlamaEngine engine = ScriptedLlamaEngine();
    await pumpLlamaPulse(tester, engine: engine);
    await _openChat(tester);

    await _loadAndGenerate(tester, engine);

    engine
      ..emitToken('Hello')
      ..emitToken(' world');
    await tester.pump();
    await tester.pump();

    expect(_outputText(tester), 'Hello world');

    final GenerationMetrics metrics = _metrics();
    engine.emitMetrics(metrics);
    await tester.pump();
    await tester.pump();

    expect(find.text('20.0 tok/s'), findsOneWidget);
    expect(find.text('20'), findsWidgets);

    engine.complete(metrics);
    await tester.pump();
    await tester.pump();

    expect(find.text('Ready'), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel-generation')), findsNothing);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Assistant'), findsOneWidget);
    expect(_turnText(tester, 0), 'Say hi');
    expect(_turnText(tester, 1), 'Hello world');
    expect(find.byKey(const ValueKey('output-text')), findsNothing);
  });

  testWidgets('cancels a running generation', (tester) async {
    _useView(tester, const Size(1400, 1000));
    final ScriptedLlamaEngine engine = ScriptedLlamaEngine();
    await pumpLlamaPulse(tester, engine: engine);
    await _openChat(tester);
    await _loadAndGenerate(tester, engine);

    engine.emitToken('Partial');
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('cancel-generation')));
    await tester.pump();
    await tester.pump();

    expect(engine.cancelledRequestIds, [engine.lastRequestId]);
    expect(find.text('Cancelling'), findsOneWidget);

    engine.cancelled();
    await tester.pump();
    await tester.pump();

    expect(find.text('Ready'), findsOneWidget);
    expect(_turnText(tester, 1), 'Partial');
    expect(find.byKey(const ValueKey('output-text')), findsNothing);
  });

  testWidgets('shows a failure and keeps partial output', (tester) async {
    _useView(tester, const Size(1400, 1000));
    final ScriptedLlamaEngine engine = ScriptedLlamaEngine();
    await pumpLlamaPulse(tester, engine: engine);
    await _openChat(tester);
    await _loadAndGenerate(tester, engine);

    engine.emitToken('Partial');
    await tester.pump();
    await tester.pump();

    engine.failed(
      InferenceFailure(
        (b) => b
          ..code = InferenceFailureCode.nativeError
          ..message = 'boom',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Error'), findsOneWidget);
    expect(find.byKey(const ValueKey('failure-banner')), findsOneWidget);
    expect(find.textContaining('nativeError'), findsOneWidget);
    expect(_turnText(tester, 0), 'Say hi');
    expect(_turnText(tester, 1), 'Partial');
    expect(find.byKey(const ValueKey('output-text')), findsNothing);
  });

  testWidgets('clears the conversation', (tester) async {
    _useView(tester, const Size(1400, 1000));
    final ScriptedLlamaEngine engine = ScriptedLlamaEngine();
    await pumpLlamaPulse(tester, engine: engine);
    await _openChat(tester);
    await _loadAndGenerate(tester, engine);

    engine.emitToken('Hello');
    await tester.pump();
    await tester.pump();

    engine.complete(_metrics());
    await tester.pump();
    await tester.pump();

    expect(_clearEnabled(tester), isTrue);
    expect(_turnText(tester, 1), 'Hello');

    await tester.tap(find.byKey(const ValueKey('clear-conversation')));
    await tester.pump();
    await tester.pump();

    expect(find.text('No messages yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-transcript')), findsNothing);
    expect(_clearEnabled(tester), isFalse);
    final InferenceBloc bloc = tester
        .element(find.byKey(const ValueKey('output-card')))
        .read<InferenceBloc>();
    expect(bloc.state.transcript, isEmpty);
  });
}

Future<void> _openChat(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('chat-tab')));
  await tester.pump();
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, String key) async {
  final Finder finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump();
}

Future<void> _enterSystemPrompt(WidgetTester tester, String text) async {
  final Finder finder = find.byKey(const ValueKey('system-prompt'));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> _saveParams(WidgetTester tester) =>
    _tapVisible(tester, 'save-params');

Future<void> _loadAndGenerate(
  WidgetTester tester,
  ScriptedLlamaEngine engine,
) async {
  await tester.enterText(
    find.byKey(const ValueKey('model-path')),
    '/models/test.gguf',
  );
  await tester.pump();
  await _tapVisible(tester, 'load-model');

  expect(find.text('Ready'), findsOneWidget);

  await tester.enterText(find.byKey(const ValueKey('prompt-field')), 'Say hi');
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('generate')));
  await tester.pump();
  await tester.pump();

  expect(engine.generatedRequests, hasLength(1));
}

GenerationMetrics _metrics() => GenerationMetrics(
  (b) => b
    ..promptTokenCount = 3
    ..generatedTokenCount = 20
    ..promptEvalMs = 250
    ..evalMs = 1000,
);

void _useView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

double _top(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dy;

String _fieldText(WidgetTester tester, String key) {
  final EditableText editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(EditableText),
    ),
  );
  return editable.controller.text;
}

String? _outputText(WidgetTester tester) {
  final SelectableText text = tester.widget<SelectableText>(
    find.byKey(const ValueKey('output-text')),
  );
  return text.data;
}

String? _turnText(WidgetTester tester, int index) {
  final SelectableText text = tester.widget<SelectableText>(
    find.byKey(ValueKey('transcript-text-$index')),
  );
  return text.data;
}

bool _clearEnabled(WidgetTester tester) =>
    tester
        .widget<TextButton>(find.byKey(const ValueKey('clear-conversation')))
        .onPressed !=
    null;
