import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/app/app.dart';

void main() {
  testWidgets('shows the honest placeholder content', (tester) async {
    await tester.pumpWidget(const LlamaPulseApp());
    await tester.pump();

    expect(find.text('LlamaPulse'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
    expect(
      find.text('No output yet. Inference is not wired in yet.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Tokens per second and eval timings appear here after a generation.',
      ),
      findsOneWidget,
    );
    expect(find.text('Defaults — not yet editable'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('lays the cards out side by side on wide windows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LlamaPulseApp());
    await tester.pump();

    final double parametersTop = tester
        .getTopLeft(find.byKey(const ValueKey('parameters-card')))
        .dy;
    final double outputTop = tester
        .getTopLeft(find.byKey(const ValueKey('output-card')))
        .dy;

    expect(parametersTop, outputTop);
  });

  testWidgets('stacks the cards on narrow windows', (tester) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LlamaPulseApp());
    await tester.pump();

    final double parametersTop = tester
        .getTopLeft(find.byKey(const ValueKey('parameters-card')))
        .dy;
    final double outputTop = tester
        .getTopLeft(find.byKey(const ValueKey('output-card')))
        .dy;

    expect(outputTop, greaterThan(parametersTop));
  });
}
