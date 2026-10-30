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

  // A hot restart runs [runLlamaPulse] again: dispose the previous hook so a
  // single exit request is not handled twice.
  _lifecycleListener?.dispose();
  // A supervised llama-server is a child of the app: closing the window must
  // stop it, otherwise the next launch finds a port already in use.
  _lifecycleListener = AppLifecycleListener(
    onExitRequested: () async {
      await disposeAppDependencies();
      return AppExitResponse.exit;
    },
  );

  runApp(buildRootApp());
}

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
