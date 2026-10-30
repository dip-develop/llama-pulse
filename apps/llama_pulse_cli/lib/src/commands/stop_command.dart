import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../server/server_output.dart';

/// Stops the server recorded in `server-state.yaml`.
///
/// The supervisor is signalled first. When the signal cannot be delivered (the
/// supervisor is already gone) the recorded `llama-server` child is signalled
/// instead, so a dead supervisor never masks a live child. A graceful signal is
/// escalated to a forced one after waiting at most
/// [CliServices.stopTimeout] for the state document to release the pids.
///
/// The command reports `stopped: true` only when the state document no longer
/// records a run: it is absent, or it is in `stopped`/`failed` and lists no
/// pids. A document that still lists them is left untouched and the command
/// exits 1. `--json` reports the pid that accepted the signal, or the last
/// target the command tried when none did.
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

    final force = parsedArgs.flag('force');
    var forced = force;
    var attempt = _signal(
      state,
      force ? ServerKillMode.force : ServerKillMode.graceful,
    );

    // A forced kill cannot be handled by the process, so only the graceful
    // attempt waits for the state document.
    if (!force && (attempt.signalled == null || !await _waitUntilGone())) {
      forced = true;
      final latest = await repository.load() ?? state;
      attempt = _signal(latest, ServerKillMode.force);
    }

    final latest = await repository.load();
    if (!_isGone(latest)) {
      services.err.writeln('error: could not stop the recorded server');
      if (json) {
        writeJsonLine(
          services.out,
          encodeServerStop(
            stopped: false,
            pid: _reportedPid(attempt),
            forced: forced,
          ),
        );
      }
      return ExitCodes.failure;
    }

    if (latest != null) {
      await _clear(latest);
    }
    return _reportStopped(
      json: json,
      pid: _reportedPid(attempt),
      forced: forced,
    );
  }

  /// Sends [mode] to the supervisor, falling back to the child when the
  /// supervisor cannot be signalled.
  ({int? signalled, int? attempted}) _signal(
    ServerState state,
    ServerKillMode mode,
  ) {
    final supervisorPid = state.supervisorPid;
    final serverPid = state.serverPid;
    if (supervisorPid != null) {
      if (services.processSignaller.send(supervisorPid, mode)) {
        return (signalled: supervisorPid, attempted: supervisorPid);
      }
      if (serverPid != null && serverPid != supervisorPid) {
        final accepted = services.processSignaller.send(serverPid, mode);
        return (signalled: accepted ? serverPid : null, attempted: serverPid);
      }
      return (signalled: null, attempted: supervisorPid);
    }
    if (serverPid != null) {
      final accepted = services.processSignaller.send(serverPid, mode);
      return (signalled: accepted ? serverPid : null, attempted: serverPid);
    }
    return (signalled: null, attempted: null);
  }

  int? _reportedPid(({int? signalled, int? attempted}) attempt) =>
      attempt.signalled ?? attempt.attempted;

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

  Future<bool> _waitUntilGone() async {
    final deadline = DateTime.now().add(services.stopTimeout);
    while (true) {
      if (_isGone(await services.serverStateRepository.load())) {
        return true;
      }
      if (DateTime.now().isAfter(deadline)) {
        return false;
      }
      await Future<void>.delayed(services.stopPollInterval);
    }
  }

  bool _isGone(ServerState? state) {
    if (state == null) {
      return true;
    }
    if (state.phase != ServerPhase.stopped &&
        state.phase != ServerPhase.failed) {
      return false;
    }
    return state.serverPid == null && state.supervisorPid == null;
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
