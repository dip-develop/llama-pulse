import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../output.dart';
import '../server/server_output.dart';
import '../server/server_status_reader.dart';

/// Reports the recorded server state, health and binary.
final class StatusCommand extends LlamaPulseCommand {
  /// Creates the command.
  StatusCommand(super.services) {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print the status as a single-line JSON object.',
    );
  }

  @override
  String get name => 'status';

  @override
  String get description =>
      'Report the supervised server state and probe its health.';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final controller = services.createServerController();
    try {
      final snapshot = await ServerStatusReader(
        stateRepository: services.serverStateRepository,
        configRepository: services.serverConfigRepository,
        controller: controller,
      ).read();
      if (parsedArgs.flag('json')) {
        writeJsonLine(services.out, encodeServerStatus(snapshot));
      } else {
        _writeHuman(snapshot);
      }
      return snapshot.exitCode;
    } finally {
      await controller.dispose();
    }
  }

  void _writeHuman(ServerStatusSnapshot snapshot) {
    final out = services.out;
    out.writeln('status: ${snapshot.status}');
    final pid = snapshot.pid;
    if (pid != null) {
      out.writeln('pid: $pid');
    }
    final supervisorPid = snapshot.supervisorPid;
    if (supervisorPid != null) {
      out.writeln('supervisorPid: $supervisorPid');
    }
    out
      ..writeln('endpoint: ${snapshot.baseUrl}')
      ..writeln('model: ${snapshot.modelPath}')
      ..writeln('binary: ${_formatBinary(snapshot.binary)}')
      ..writeln('health: ${snapshot.health}');
    final uptime = snapshot.uptimeSeconds;
    if (uptime != null) {
      out.writeln('uptime: ${uptime}s');
    }
    final failure = snapshot.failure;
    if (failure != null) {
      out.writeln('failure: ${failure.code.name}: ${failure.message}');
    }
  }

  String _formatBinary(ServerBinaryInfo? binary) {
    if (binary == null) {
      return 'not found';
    }
    final build = binary.buildNumber;
    final suffix = build == null
        ? binary.version
        : '${binary.version}, build $build';
    return '${binary.path} ($suffix)';
  }
}
