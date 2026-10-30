import 'dart:isolate';

/// Bootstrap message handed to the worker isolate when it is spawned.
///
/// One of the two deliberate non-`built_value` transport types: a [SendPort]
/// cannot be serialized, and this object never leaves the isolate plumbing.
final class WorkerConfig {
  /// Creates a config whose worker answers on [mainPort].
  const WorkerConfig({required this.mainPort});

  /// Port of the spawning isolate: the worker sends [WorkerReady] and every
  /// worker response to it.
  final SendPort mainPort;
}

/// First message a spawned worker sends back to its spawner.
///
/// The spawner keeps [responsePort] and sends every worker request there. It is
/// the second of the two non-`built_value` transport types.
final class WorkerReady {
  /// Creates the handshake message carrying [responsePort].
  const WorkerReady({required this.responsePort});

  /// Port the worker listens on for requests.
  final SendPort responsePort;
}
