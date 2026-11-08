import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_bloc.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_event.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_status.dart';
import 'package:llama_pulse/presentation/inference/widgets/conversation_view.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../support/scripted_llama_engine.dart';

const ModelParamsValidator _validator = ModelParamsValidator();

final String _longText = List<String>.generate(
  40,
  (index) => 'Line $index of a transcript tall enough to scroll.',
).join('\n');

ModelParams _validParams() =>
    ModelParams.defaults().copyWith(modelPath: '/models/model.gguf');

Widget _buildView(InferenceBloc bloc) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      height: 320,
      child: BlocProvider<InferenceBloc>.value(
        value: bloc,
        child: const ConversationView(),
      ),
    ),
  ),
);

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  InferenceBloc? bloc,
}) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (condition()) {
      return;
    }
    await tester.pump(Duration.zero);
  }
  throw StateError(
    'condition was not met: ${bloc?.state.status} ${bloc?.state.failure}',
  );
}

/// Loads the model, pumps the view and starts a generation with a long user
/// turn and a long first draft, so the transcript can scroll.
///
/// The bloc is built inside the test body, never in `setUp`: `testWidgets`
/// runs in a fake-async zone, and a bloc created in the outer zone never
/// finishes the repository and engine futures that a pump advances.
Future<
  ({
    ScriptedLlamaEngine engine,
    InferenceBloc bloc,
    ScrollController controller,
  })
>
_startScrolledGeneration(WidgetTester tester) async {
  final InMemoryConfigStore store = InMemoryConfigStore();
  final YamlModelParamsRepository repository = YamlModelParamsRepository(
    store: store,
    serializers: serializers,
    validator: _validator,
  );
  final ScriptedLlamaEngine engine = ScriptedLlamaEngine();
  final InferenceBloc bloc = InferenceBloc(
    LoadModelParams(repository),
    SaveModelParams(repository, _validator),
    _validator,
    engine,
  );
  addTearDown(bloc.close);

  bloc.add(InferenceParamsChanged(_validParams()));
  bloc.add(InferencePromptChanged(_longText));
  bloc.add(const InferenceLoadRequested());
  await tester.pumpWidget(_buildView(bloc));
  await _pumpUntil(
    tester,
    () => bloc.state.status == InferenceStatus.modelReady,
    bloc: bloc,
  );

  bloc.add(const InferenceGenerateRequested());
  await _pumpUntil(tester, () => engine.generatedRequests.isNotEmpty);
  engine.emitToken(_longText);
  await _pumpUntil(tester, () => bloc.state.output.isNotEmpty);
  // One more frame runs the post-layout jump to the bottom.
  await tester.pump();

  final ListView list = tester.widget<ListView>(
    find.byKey(const ValueKey('chat-transcript')),
  );
  expect(list.controller!.position.maxScrollExtent, greaterThan(0));
  return (engine: engine, bloc: bloc, controller: list.controller!);
}

void main() {
  testWidgets('does not follow a token when the reader scrolled up', (
    tester,
  ) async {
    final harness = await _startScrolledGeneration(tester);
    final ScrollController controller = harness.controller;

    await tester.timedDrag(
      find.byKey(const ValueKey('chat-transcript')),
      const Offset(0, 400),
      const Duration(milliseconds: 500),
    );
    await tester.pump();
    final double scrolledUp = controller.offset;
    expect(
      scrolledUp,
      lessThan(controller.position.maxScrollExtent - 8),
      reason: 'the drag must leave the view well above the bottom',
    );

    harness.engine.emitToken('\nA fresh line while the reader is away.');
    await _pumpUntil(
      tester,
      () => harness.bloc.state.output.contains('A fresh line'),
    );
    await tester.pump();

    expect(controller.offset, scrolledUp);
  });

  testWidgets('follows a token when the reader is at the bottom', (
    tester,
  ) async {
    final harness = await _startScrolledGeneration(tester);
    final ScrollController controller = harness.controller;
    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent, 1),
      reason: 'a fresh transcript starts at its newest turn',
    );
    final double before = controller.offset;

    harness.engine.emitToken('\nAnother line at the bottom.');
    await _pumpUntil(
      tester,
      () => harness.bloc.state.output.contains('Another line at the bottom.'),
    );
    await tester.pump();

    expect(controller.position.maxScrollExtent, greaterThan(before));
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, 1));
  });
}
