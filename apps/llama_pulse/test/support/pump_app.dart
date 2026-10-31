import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/app/app.dart';
import 'package:llama_pulse/app/di/injection.dart';
import 'package:llama_pulse/app/platform/clipboard_service.dart';
import 'package:llama_pulse/app/platform/model_path_picker.dart';
import 'package:llama_pulse/app/platform/server_binary_picker.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import 'fake_clipboard_service.dart';
import 'fake_model_path_picker.dart';
import 'fake_server_binary_picker.dart';
import 'fake_server_controller.dart';

/// Pumps the app with a throwaway configuration directory and optional fakes.
///
/// GetIt is reset before and after the test so widget tests never share
/// registrations. The file dialogs and the clipboard are replaced by fakes,
/// and a [FakeServerController] stands in for the supervisor unless the caller
/// passes its own, so no test spawns a process or reaches a platform plugin.
///
/// A [recordedState] is written to the shared state document before the first
/// frame, as if a CLI run had left it behind.
Future<void> pumpLlamaPulse(
  WidgetTester tester, {
  ServerController? serverController,
  LlamaEngine? engine,
  ModelPathPicker? picker,
  ServerBinaryPicker? binaryPicker,
  ClipboardService? clipboard,
  ServerState? recordedState,
  bool demoServer = false,
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

  final ServerController controller =
      serverController ?? FakeServerController();

  await getIt.reset();
  await configureDependencies(
    paths: AppPaths(configDirectory: tempDir.path),
    configStore: InMemoryConfigStore(),
    engine: engine,
    serverController: controller,
  );
  if (recordedState != null) {
    await getIt<ServerStateRepository>().save(recordedState);
  }

  await tester.pumpWidget(
    LlamaPulseApp(
      picker: picker ?? FakeModelPathPicker(),
      binaryPicker: binaryPicker ?? FakeServerBinaryPicker(),
      clipboard: clipboard ?? FakeClipboardService(),
      demoServer: demoServer,
      demoEngine: demoEngine,
    ),
  );
  // One pump renders the first frame, the next flush `Started` for both blocs,
  // and one more lets the supervisor's binary probe resolve.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}
