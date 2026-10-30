import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/app/app.dart';
import 'package:llama_pulse/app/di/injection.dart';
import 'package:llama_pulse/app/platform/model_path_picker.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import 'fake_model_path_picker.dart';

/// Pumps the app with a throwaway configuration directory and optional engine.
///
/// GetIt is reset before and after the test so widget tests never share
/// registrations; the file-dialog plugin is replaced by [picker] unless the
/// caller passes its own.
Future<void> pumpLlamaPulse(
  WidgetTester tester, {
  LlamaEngine? engine,
  ModelPathPicker? picker,
  bool demoEngine = false,
}) async {
  // Synchronous I/O: `testWidgets` runs in a fake-async zone, where awaiting
  // real file-system futures deadlocks.
  final Directory tempDir = Directory.systemTemp.createTempSync(
    'llama_pulse_widget_test',
  );
  addTearDown(() async {
    await getIt.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  await getIt.reset();
  await configureDependencies(
    paths: AppPaths(configDirectory: tempDir.path),
    configStore: InMemoryConfigStore(),
    engine: engine,
  );

  await tester.pumpWidget(
    LlamaPulseApp(
      picker: picker ?? FakeModelPathPicker(),
      demoEngine: demoEngine,
    ),
  );
  // One pump renders the first frame, the second flushes InferenceStarted.
  await tester.pump();
  await tester.pump();
}
