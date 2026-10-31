import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import 'app.dart';
import 'di/injection.dart';

/// Whether the stub engine is opted into at compile time.
///
/// The flag is a `bool.fromEnvironment`, so a release build can never silently
/// emit synthetic tokens: it requires `--dart-define` at build time.
const bool stubEngineEnabled = bool.fromEnvironment('LLAMAPULSE_STUB_ENGINE');

/// Whether the synthetic server controller is opted into at compile time.
const bool stubServerEnabled = bool.fromEnvironment('LLAMAPULSE_STUB_SERVER');

/// Keeps the exit listener registered with the widget binding alive.
AppLifecycleListener? _lifecycleListener;

/// Watchers for [ProcessSignal.sigterm] and [ProcessSignal.sigint].
final List<StreamSubscription<ProcessSignal>> _signalWatchers = [];

/// Whether a termination signal is already being handled.
///
/// A second signal must not wait for the first teardown: it exits at once.
bool _terminationInProgress = false;

/// Whether this platform delivers POSIX termination signals.
///
/// Windows has no `sigterm`/`sigint` streams; tests check this guard directly
/// instead of raising a real process signal.
bool get supportsTerminationSignals => !Platform.isWindows;

/// Builds the root widget with the compile-time demo flags applied.
///
/// Both flags come from `--dart-define`, so the demo banners can only appear in
/// a build that explicitly opted into a stub.
LlamaPulseApp buildRootApp() =>
    LlamaPulseApp(demoEngine: stubEngineEnabled, demoServer: stubServerEnabled);

/// Starts LlamaPulse, wiring dependencies and installing a global error
/// handler that reports failures instead of tearing down the frame loop.
Future<void> runLlamaPulse() async {
  WidgetsFlutterBinding.ensureInitialized();

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Unhandled error: $error\n$stack');
    return true;
  };

  await configureDependencies(
    useStubEngine: stubEngineEnabled,
    useStubServer: stubServerEnabled,
  );

  await _watchTerminationSignals();

  // A hot restart runs [runLlamaPulse] again: dispose the previous hook so a
  // single exit request is not handled twice.
  _lifecycleListener?.dispose();
  // A supervised llama-server is a child of the app: closing the window must
  // stop it, otherwise the next launch finds a port already in use.
  _lifecycleListener = AppLifecycleListener(
    onExitRequested: () async {
      await _cancelSignalWatchers();
      await disposeAppDependencies();
      return AppExitResponse.exit;
    },
  );

  runApp(buildRootApp());
}

/// Watches the POSIX termination signals once, when the platform has them.
Future<void> _watchTerminationSignals() async {
  await _cancelSignalWatchers();
  if (!supportsTerminationSignals) {
    return;
  }
  _signalWatchers
    ..add(
      ProcessSignal.sigterm.watch().listen(
        (ProcessSignal signal) => unawaited(handleTerminationSignal(signal)),
      ),
    )
    ..add(
      ProcessSignal.sigint.watch().listen(
        (ProcessSignal signal) => unawaited(handleTerminationSignal(signal)),
      ),
    );
}

Future<void> _cancelSignalWatchers() async {
  final List<StreamSubscription<ProcessSignal>> watchers = List.of(
    _signalWatchers,
  );
  _signalWatchers.clear();
  for (final StreamSubscription<ProcessSignal> watcher in watchers) {
    await watcher.cancel();
  }
}

/// Handles one termination signal: tears the app down, then exits.
///
/// SIGTERM exits with 0 and SIGINT with 130, the conventional shell code for
/// an interrupted process. A second signal exits immediately instead of
/// waiting for the first teardown to finish.
///
/// [exitProcess] is a seam so tests can observe the code without ending the
/// test process.
Future<void> handleTerminationSignal(
  ProcessSignal signal, {
  void Function(int exitCode) exitProcess = _exitProcess,
}) async {
  final int code = signal == ProcessSignal.sigint ? 130 : 0;
  if (_terminationInProgress) {
    exitProcess(code);
    return;
  }
  _terminationInProgress = true;
  try {
    await disposeAppDependencies();
  } on Object catch (error, stack) {
    debugPrint('Could not tear down on $signal: $error\n$stack');
  }
  await _cancelSignalWatchers();
  exitProcess(code);
}

void _exitProcess(int code) => exit(code);

/// Disposes the app-wide singletons so no server process outlives the window.
///
/// Safe to call more than once and when the dependencies were already torn
/// down: disposing is idempotent, and a failure to dispose is logged rather
/// than blocking the exit.
Future<void> disposeAppDependencies() async {
  if (!getIt.isRegistered<ServerController>()) {
    return;
  }
  try {
    await getIt<ServerController>().dispose();
  } on Object catch (error, stack) {
    debugPrint('Could not dispose the server controller: $error\n$stack');
  }
}
