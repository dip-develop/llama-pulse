import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';

/// Starts LlamaPulse after binding the engine and installing a global error
/// handler that reports failures instead of tearing down the frame loop.
Future<void> runLlamaPulse() async {
  WidgetsFlutterBinding.ensureInitialized();

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Unhandled error: $error\n$stack');
    return true;
  };

  runApp(const LlamaPulseApp());
}
