// The fields are private but the constructor parameters are public API, so the
// initializing-formal rewrite would leak private names.
// ignore_for_file: prefer_initializing_formals
import 'package:llama_pulse_core/llama_pulse_core.dart';

int _nowEpochMs() => DateTime.now().millisecondsSinceEpoch;

/// The message [ServerController.testConnection] reports for an HTTP 200 whose
/// body is not `{"status":"ok"}`.
///
/// That is how `llama-server` answers `/health` while it still loads the model,
/// so the server is answering but is not healthy yet.
const String _httpOkMessage = 'HTTP 200';

/// A point-in-time view of the supervised server, for `status` and `serve`.
final class ServerStatusSnapshot {
  /// Creates a snapshot.
  const ServerStatusSnapshot({
    required this.running,
    required this.status,
    required this.health,
    required this.pid,
    required this.supervisorPid,
    required this.host,
    required this.port,
    required this.baseUrl,
    required this.modelPath,
    required this.binary,
    required this.uptimeSeconds,
    required this.lastExitCode,
    required this.failure,
  });

  /// Whether a recorded server answered `/health` in the running phase.
  ///
  /// An answer of `{"status":"loading"}` counts: the process is up, but the run
  /// is not healthy yet, so [exitCode] stays non-zero.
  final bool running;

  /// Human-readable status: `running`, `stopped`, `stale` or a phase name.
  final String status;

  /// Human-readable health: `ok`, `unknown`, `unreachable` or a health name.
  final String health;

  /// `llama-server` process id, when recorded.
  final int? pid;

  /// Supervisor process id, when recorded.
  final int? supervisorPid;

  /// Address the recorded server binds to.
  final String host;

  /// Port the recorded server listens on.
  final int port;

  /// OpenAI-compatible endpoint root.
  final String baseUrl;

  /// Model path the server was started with.
  final String modelPath;

  /// Resolved binary, or null when no runnable executable exists.
  final ServerBinaryInfo? binary;

  /// Seconds since the server started, while a run is recorded.
  final int? uptimeSeconds;

  /// Exit code of the last finished process, when recorded.
  final int? lastExitCode;

  /// Failure recorded in the state document, when any.
  final ServerFailure? failure;

  /// Process exit code implied by the snapshot: 0 only for a healthy server.
  int get exitCode => running && health == ServerHealth.ok.name ? 0 : 1;
}

/// The two facts `status` needs from one `/health` probe.
final class _Probe {
  const _Probe({required this.reachable, required this.healthy});

  /// The server answered and is accepting requests.
  final bool reachable;

  /// The answer was a 200 with `{"status":"ok"}`.
  final bool healthy;
}

/// Reads `server-state.yaml` and probes the recorded server.
final class ServerStatusReader {
  /// Creates a reader over the repositories and [controller].
  const ServerStatusReader({
    required ServerStateRepository stateRepository,
    required ServerConfigRepository configRepository,
    required ServerController controller,
    int Function() clock = _nowEpochMs,
  }) : _stateRepository = stateRepository,
       _configRepository = configRepository,
       _controller = controller,
       _clock = clock;

  final ServerStateRepository _stateRepository;
  final ServerConfigRepository _configRepository;
  final ServerController _controller;
  final int Function() _clock;

  /// Probes the recorded server for the "already running" guard.
  ///
  /// Returns true only when the state document records `starting`, `running`
  /// or `stopping` **and** `/health` answers. A stale state document returns
  /// false. `stopping` counts because the previous run still owns the process
  /// until it has exited.
  Future<bool> recordedServerAnswers({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final state = await _stateRepository.load();
    if (state == null) {
      return false;
    }
    if (state.phase != ServerPhase.starting &&
        state.phase != ServerPhase.running &&
        state.phase != ServerPhase.stopping) {
      return false;
    }
    final config = await _effectiveConfig(state);
    return (await _probe(config, timeout)).reachable;
  }

  /// Reads the state document, locates the binary and probes a live server.
  Future<ServerStatusSnapshot> read({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final state = await _stateRepository.load();
    final config = await _effectiveConfig(state);

    ServerBinaryInfo? binary;
    try {
      binary = await _controller.locateBinary(config);
    } on ServerException {
      binary = null;
    } catch (_) {
      binary = null;
    }

    final probe = state != null && state.isActive
        ? await _probe(config, timeout)
        : const _Probe(reachable: false, healthy: false);

    final baseUrl = state?.baseUrl ?? config.baseUrl;
    final modelPath = state != null && state.modelPath.isNotEmpty
        ? state.modelPath
        : config.modelPath;

    final String status;
    final String health;
    if (state == null) {
      status = ServerPhase.stopped.name;
      health = ServerHealth.unknown.name;
    } else if (!state.isActive) {
      status = state.phase.name;
      health = state.health.name;
    } else if (!probe.reachable) {
      status = 'stale';
      health = ServerHealth.unreachable.name;
    } else {
      status = state.phase == ServerPhase.running
          ? ServerPhase.running.name
          : state.phase.name;
      health = probe.healthy ? ServerHealth.ok.name : ServerHealth.loading.name;
    }
    final running = status == ServerPhase.running.name;

    return ServerStatusSnapshot(
      running: running,
      status: status,
      health: health,
      pid: state?.serverPid,
      supervisorPid: state?.supervisorPid,
      host: state?.host ?? config.host,
      port: state?.port ?? config.port,
      baseUrl: baseUrl,
      modelPath: modelPath,
      binary: binary,
      uptimeSeconds: state == null || !state.isActive
          ? null
          : _uptimeSeconds(state.startedAtEpochMs),
      lastExitCode: state?.lastExitCode,
      failure: state?.failure,
    );
  }

  int? _uptimeSeconds(int? startedAtEpochMs) {
    if (startedAtEpochMs == null) {
      return null;
    }
    final elapsed = _clock() - startedAtEpochMs;
    return elapsed < 0 ? 0 : elapsed ~/ 1000;
  }

  Future<_Probe> _probe(ServerConfig config, Duration timeout) async {
    final probe = await _controller
        .testConnection(config)
        .timeout(
          timeout,
          onTimeout: () => const ServerProbeResult(
            ok: false,
            latencyMs: 0,
            message: 'unreachable',
          ),
        );
    if (probe.ok) {
      return const _Probe(reachable: true, healthy: true);
    }
    return _Probe(reachable: probe.message == _httpOkMessage, healthy: false);
  }

  Future<ServerConfig> _effectiveConfig(ServerState? state) async {
    var config = await _configRepository.load();
    if (state == null) {
      return config;
    }
    config = config.copyWith(
      host: state.host,
      port: state.port,
      modelPath: state.modelPath.isNotEmpty ? state.modelPath : null,
      binaryPath: state.binaryPath.isNotEmpty ? state.binaryPath : null,
    );
    return config;
  }
}
