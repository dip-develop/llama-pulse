import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/presentation/runtime/bloc/runtime_bloc.dart';
import 'package:llama_pulse/presentation/runtime/bloc/runtime_event.dart';
import 'package:llama_pulse/presentation/runtime/bloc/runtime_state.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../support/fake_runtime.dart';

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 500; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('the runtime bloc did not reach the expected state');
}

Future<void> _drain() async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
}

RuntimeManifest _manifest({
  RuntimeBackend backend = RuntimeBackend.cpu,
  String version = '0.8.0-dev',
}) => RuntimeManifest(
  (b) => b
    ..tag = 'v0.8.0'
    ..buildId = 'b11960'
    ..commit = '8642541b255bfb5dc39cd351a178be09013a55d6'
    ..backend = backend
    ..platform = RuntimePlatform.linuxX64
    ..assetName = backend == RuntimeBackend.cpu
        ? 'llama-b11960-bin-ubuntu-x64.tar.gz'
        : 'llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz'
    ..sha256 = 'a' * 64
    ..sizeBytes = 1000
    ..installedAtEpochMs = 10
    ..llamaVersion = version
    ..buildNumber = 11960
    ..files = 4,
);

RuntimeDetection _unsupported() => RuntimeDetection(
  hardware: RuntimeHardware(
    operatingSystem: 'linux',
    arch: 'arm64',
    platform: null,
  ),
  supports: const <BackendSupport>[],
);

void main() {
  late FakeRuntimeStore store;
  late FakeRuntimeInstallService installer;

  setUp(() {
    store = FakeRuntimeStore();
    installer = FakeRuntimeInstallService(
      release: testRuntimeRelease(),
      store: store,
    );
  });

  RuntimeBloc build({
    FakeRuntimeInstallService? withInstaller,
    RuntimeDetection? detection,
  }) {
    final RuntimeBloc bloc = RuntimeBloc(
      RuntimeStatusReader(
        store: store,
        probe: FakeRuntimeProbe(detection: detection),
        release: testRuntimeRelease(),
      ),
      withInstaller ?? installer,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  test('started loads the host, the backends and the gate', () async {
    store.seed(_manifest(), selected: true);
    final RuntimeBloc bloc = build();

    bloc.add(const RuntimeStarted());
    await _waitUntil(() => !bloc.state.loading);

    final RuntimeState state = bloc.state;
    expect(state.hardwareSummary, contains('RTX 4090'));
    expect(state.platform, RuntimePlatform.linuxX64);
    expect(state.recommendedBackend, RuntimeBackend.cuda13);
    expect(
      state.offeredBackends.map((b) => b.id),
      containsAll(<String>['cpu', 'cuda13', 'vulkan']),
    );
    expect(state.installed, hasLength(1));
    expect(state.selectedId, 'v0.8.0/cpu');
    expect(state.selectedVersion, '0.8.0-dev');
    expect(state.gateVerdict, RuntimeGateVerdict.attested);
    expect(state.gateAccepted, isTrue);
    expect(state.isSupported(RuntimeBackend.vulkan), isFalse);
  });

  test('an unsupported host offers nothing', () async {
    final RuntimeBloc bloc = build(detection: _unsupported());

    bloc.add(const RuntimeStarted());
    await _waitUntil(() => !bloc.state.loading);

    expect(bloc.state.platform, isNull);
    expect(bloc.state.offeredBackends, isEmpty);
    expect(bloc.state.gateVerdict, RuntimeGateVerdict.notInstalled);
  });

  test('install reports progress and refreshes the index', () async {
    final RuntimeBloc bloc = build();
    bloc.add(const RuntimeStarted());
    await _waitUntil(() => !bloc.state.loading);

    bloc.add(const RuntimeInstallRequested(RuntimeBackend.cpu));
    await _waitUntil(() => !bloc.state.installing && !bloc.state.busy);
    await _drain();

    expect(installer.installedBackends, <RuntimeBackend>[RuntimeBackend.cpu]);
    expect(bloc.state.errorMessage, isNull);
    expect(bloc.state.noticeMessage, contains('Installed CPU'));
    expect(bloc.state.installed, hasLength(1));
    expect(bloc.state.progressFraction, 1);
  });

  test('install passes force through', () async {
    store.seed(_manifest());
    final RuntimeBloc bloc = build();
    bloc.add(const RuntimeStarted());
    await _waitUntil(() => !bloc.state.loading);

    bloc.add(const RuntimeInstallRequested(RuntimeBackend.cpu, force: true));
    await _waitUntil(() => !bloc.state.installing && !bloc.state.busy);
    await _drain();

    expect(installer.installedBackends, hasLength(1));
    expect(bloc.state.installed, hasLength(1));
  });

  test('cancel stops a held install', () async {
    final FakeRuntimeInstallService held = FakeRuntimeInstallService(
      release: testRuntimeRelease(),
      store: store,
      holdUntilCancelled: true,
    );
    final RuntimeBloc bloc = build(withInstaller: held);
    bloc.add(const RuntimeStarted());
    await _waitUntil(() => !bloc.state.loading);

    bloc.add(const RuntimeInstallRequested(RuntimeBackend.cpu));
    await _waitUntil(() => bloc.state.installing);

    bloc.add(const RuntimeCancelRequested());
    await _waitUntil(() => !bloc.state.installing);
    await _drain();

    expect(bloc.state.noticeMessage, contains('cancelled'));
    expect(bloc.state.errorMessage, isNull);
  });

  test('a failed install surfaces its message', () async {
    final FakeRuntimeInstallService failing = FakeRuntimeInstallService(
      release: testRuntimeRelease(),
      store: store,
      error: const RuntimeException(
        RuntimeFailureCode.checksumMismatch,
        'archive failed SHA-256 verification',
      ),
    );
    final RuntimeBloc bloc = build(withInstaller: failing);
    bloc.add(const RuntimeStarted());
    await _waitUntil(() => !bloc.state.loading);

    bloc.add(const RuntimeInstallRequested(RuntimeBackend.cpu));
    await _waitUntil(() => !bloc.state.installing);
    await _drain();

    expect(bloc.state.errorMessage, contains('SHA-256'));
  });

  test('select and remove drive the store', () async {
    store.seed(_manifest());
    final RuntimeBloc bloc = build();
    bloc.add(const RuntimeStarted());
    await _waitUntil(() => !bloc.state.loading);

    bloc.add(const RuntimeSelectRequested('v0.8.0', RuntimeBackend.cpu));
    await _waitUntil(() => store.selectCalls == 1 && !bloc.state.busy);
    await _drain();
    expect(bloc.state.selectedId, 'v0.8.0/cpu');

    bloc.add(const RuntimeRemoveRequested('v0.8.0', RuntimeBackend.cpu));
    await _waitUntil(() => store.removeCalls == 1 && !bloc.state.busy);
    await _drain();
    expect(bloc.state.installed, isEmpty);
    expect(bloc.state.noticeMessage, contains('Removed'));
  });

  test(
    'an install on an unsupported host is rejected before the download',
    () async {
      final RuntimeBloc bloc = build(detection: _unsupported());
      bloc.add(const RuntimeStarted());
      await _waitUntil(() => !bloc.state.loading);

      bloc.add(const RuntimeInstallRequested(RuntimeBackend.cpu));
      await _drain();

      expect(installer.installedBackends, isEmpty);
      expect(bloc.state.errorMessage, contains('not available'));
    },
  );
}
