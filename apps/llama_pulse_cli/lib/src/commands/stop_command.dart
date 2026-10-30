import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../server/server_output.dart';

/// Stops the server recorded in `server-state.yaml`.
///
/// The supervisor is asked to stop first. When it is gone or inert, the command
/// signals the server process directly, waits for the state document to release
/// the pids and forces the process when it lingers.
final class StopCommand extends LlamaPulseCommand {
  /// Creates the command.
  StopCommand(super.services) {
    argParser
      ..addFlag(
        'force',
        negatable: false,
        help: 'Skip the graceful phase and terminate immediately.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print the result as a single-line JSON object.',
      );
  }

  @override
  String get name => 'stop';

  @override
  String get description => 'Stop the recorded llama-server process.';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final json = parsedArgs.flag('json');
    final repository = services.serverStateRepository;
    final state = await repository.load();
    if (state == null || !state.isActive) {
      return _reportStopped(json: json, pid: null, forced: false);
    }

    final pid = state.supervisorPid ?? state.serverPid;
    if (pid == null) {
      await _clear(state);
      return _reportStopped(json: json, pid: null, forced: false);
    }

    final force = parsedArgs.flag('force');
    var gone = false;
    var forced = false;
    if (!force) {
      services.processSignaller.send(pid, ServerKillMode.graceful);
      gone = await _waitUntilGone(pid);
    }

    if (!gone) {
      forced = true;
      final forceSent = services.processSignaller.send(
        pid,
        ServerKillMode.force,
      );
      gone = forceSent;
    }

    final latest = await repository.load();
    if (latest != null &&
        latest.isActive &&
        (latest.supervisorPid == pid || latest.serverPid == pid)) {
      await _clear(latest);
    }

    if (!gone) {
      services.err.writeln('error: could not stop the recorded server');
      if (json) {
        writeJsonLine(
          services.out,
          encodeServerStop(stopped: false, pid: pid, forced: forced),
        );
      }
      return ExitCodes.failure;
    }
    return _reportStopped(json: json, pid: pid, forced: forced);
  }

  int _reportStopped({
    required bool json,
    required int? pid,
    required bool forced,
  }) {
    if (json) {
      writeJsonLine(
        services.out,
        encodeServerStop(stopped: true, pid: pid, forced: forced),
      );
    } else {
      services.out.writeln(pid == null ? 'not running' : 'stopped');
    }
    return ExitCodes.ok;
  }

  Future<bool> _waitUntilGone(int pid) async {
    final deadline = DateTime.now().add(services.stopTimeout);
    while (true) {
      final state = await services.serverStateRepository.load();
      if (state == null ||
          !state.isActive ||
          (state.supervisorPid != pid && state.serverPid != pid)) {
        return true;
      }
      if (DateTime.now().isAfter(deadline)) {
        return false;
      }
      await Future<void>.delayed(services.stopPollInterval);
    }
  }

  Future<void> _clear(ServerState state) => services.serverStateRepository.save(
    state.rebuild(
      (b) => b
        ..phase = ServerPhase.stopped
        ..supervisorPid = null
        ..serverPid = null
        ..updatedAtEpochMs = DateTime.now().millisecondsSinceEpoch,
    ),
  );
}
