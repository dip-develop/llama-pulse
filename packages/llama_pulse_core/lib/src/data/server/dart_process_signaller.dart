import 'dart:io';

import '../../domain/gateways/process_signaller.dart';
import '../../domain/gateways/server_process.dart';

/// Signals processes through `dart:io`.
final class DartProcessSignaller implements ProcessSignaller {
  /// Creates a signaller.
  const DartProcessSignaller();

  @override
  bool send(int pid, ServerKillMode mode) {
    if (pid <= 0) {
      return false;
    }
    try {
      if (Platform.isWindows) {
        return Process.killPid(pid);
      }
      return Process.killPid(
        pid,
        mode == ServerKillMode.force
            ? ProcessSignal.sigkill
            : ProcessSignal.sigterm,
      );
    } on ProcessException {
      return false;
    } on ArgumentError {
      return false;
    }
  }
}
