import 'server_process.dart';

/// Signals a process by id, for cleanup after the handle is gone.
///
/// Test seam: lets supervisor tests observe stop requests without processes.
abstract interface class ProcessSignaller {
  /// Sends the signal for [mode]; false when the process is gone or invalid.
  bool send(int pid, ServerKillMode mode);
}
