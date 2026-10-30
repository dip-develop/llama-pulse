import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'di/injection.dart';

/// Starts LlamaPulse, wiring dependencies and installing a global error
/// handler that reports failures instead of tearing down the frame loop.
Future<void> runLlamaPulse() async {
  WidgetsFlutterBinding.ensureInitialized();

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Unhandled error: $error\n$stack');
    return true;
  };

  // Compile-time opt-in only, so a release build can never silently emit
  // synthetic tokens or run a fake server.
  const bool stubEngineEnabled = bool.fromEnvironment('LLAMAPULSE_STUB_ENGINE');
  const bool stubServerEnabled = bool.fromEnvironment('LLAMAPULSE_STUB_SERVER');
  await configureDependencies(
    useStubEngine: stubEngineEnabled,
    useStubServer: stubServerEnabled,
  );

  runApp(LlamaPulseApp(demoEngine: stubEngineEnabled));
}
