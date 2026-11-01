import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../support/fake_runtime.dart';
import '../../support/pump_app.dart';

RuntimeManifest _manifest() => RuntimeManifest(
  (b) => b
    ..tag = 'v0.8.0'
    ..buildId = 'b11960'
    ..commit = '8642541b255bfb5dc39cd351a178be09013a55d6'
    ..backend = RuntimeBackend.cpu
    ..platform = RuntimePlatform.linuxX64
    ..assetName = 'llama-b11960-bin-ubuntu-x64.tar.gz'
    ..sha256 = 'a' * 64
    ..sizeBytes = 1000
    ..installedAtEpochMs = 10
    ..llamaVersion = '0.8.0-dev'
    ..buildNumber = 11960
    ..files = 4,
);

Future<void> _openRuntimeTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('runtime-tab')).first);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('the dashboard shows a compact runtime card', (tester) async {
    await pumpLlamaPulse(tester);

    expect(find.byKey(const ValueKey('runtime-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('runtime-recommended-chip')),
      findsOneWidget,
    );
    expect(find.text('Detecting…'), findsNothing);
    expect(
      find.byKey(const ValueKey('runtime-install-button')),
      findsOneWidget,
    );
  });

  testWidgets('the runtime tab lists the backends and the gate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final FakeRuntimeStore store = FakeRuntimeStore()..seed(_manifest());
    await pumpLlamaPulse(tester, runtimeStore: store);

    await _openRuntimeTab(tester);

    expect(find.text('LlamaPulse — Runtime'), findsOneWidget);
    expect(find.byKey(const ValueKey('runtime-screen')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('runtime-hardware-summary')),
      findsOneWidget,
    );
    expect(find.textContaining('RTX 4090'), findsWidgets);
    expect(find.byKey(const ValueKey('runtime-backend-cpu')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('runtime-backend-cuda13')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('runtime-backend-vulkan')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('runtime-install-vulkan')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('runtime-install-vulkan')),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.byKey(const ValueKey('runtime-installed-v0.8.0-cpu')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('runtime-gate')), findsOneWidget);
  });

  testWidgets('installing from the card asks for size and driver floor', (
    tester,
  ) async {
    final FakeRuntimeStore store = FakeRuntimeStore();
    final FakeRuntimeInstallService installer = FakeRuntimeInstallService(
      release: testRuntimeRelease(),
      store: store,
    );
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpLlamaPulse(
      tester,
      runtimeStore: store,
      runtimeInstallService: installer,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('runtime-install-button')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('runtime-install-button')));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('runtime-install-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('Driver requirement'), findsOneWidget);
    expect(find.textContaining('CUDA runtime'), findsWidgets);
    expect(find.textContaining('MiB'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('runtime-install-confirm')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(installer.installedBackends, <RuntimeBackend>[
      RuntimeBackend.cuda13,
    ]);
    await tester.pump();
    await tester.pump();
    expect(store.manifests.keys, contains('v0.8.0/cuda13'));
    expect(find.byKey(const ValueKey('runtime-error')), findsNothing);
  });

  testWidgets('a running install can be cancelled from the tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final FakeRuntimeStore store = FakeRuntimeStore();
    final FakeRuntimeInstallService installer = FakeRuntimeInstallService(
      release: testRuntimeRelease(),
      store: store,
      holdUntilCancelled: true,
    );
    await pumpLlamaPulse(
      tester,
      runtimeStore: store,
      runtimeInstallService: installer,
    );
    await _openRuntimeTab(tester);

    await tester.tap(find.byKey(const ValueKey('runtime-install-cpu')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('runtime-install-confirm')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('runtime-tab-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('runtime-tab-cancel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('runtime-tab-cancel')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byKey(const ValueKey('runtime-tab-progress')), findsNothing);
    expect(find.byKey(const ValueKey('runtime-tab-notice')), findsOneWidget);
    expect(find.textContaining('cancelled'), findsWidgets);
  });

  testWidgets('removing an install asks for confirmation', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final FakeRuntimeStore store = FakeRuntimeStore()..seed(_manifest());
    await pumpLlamaPulse(tester, runtimeStore: store);
    await _openRuntimeTab(tester);

    await tester.tap(find.byKey(const ValueKey('runtime-remove-cpu')));
    await tester.pump();

    expect(find.byKey(const ValueKey('runtime-remove-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('runtime-remove-confirm')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(store.removeCalls, 1);
    expect(store.manifests, isEmpty);
  });

  testWidgets('an unsupported host disables install', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final FakeRuntimeProbe probe = FakeRuntimeProbe(
      detection: RuntimeDetection(
        hardware: RuntimeHardware(
          operatingSystem: 'linux',
          arch: 'arm64',
          platform: null,
        ),
        supports: const <BackendSupport>[],
      ),
    );
    await pumpLlamaPulse(tester, runtimeProbe: probe);
    await _openRuntimeTab(tester);

    expect(find.byKey(const ValueKey('runtime-unsupported')), findsOneWidget);
  });
}
