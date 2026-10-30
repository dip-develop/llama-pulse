// The fields are private but the constructor parameters are public API, so the
// initializing-formal rewrite would leak private names.
// ignore_for_file: prefer_initializing_formals
import 'package:llama_pulse_core/llama_pulse_core.dart';

int _nowEpochMs() => DateTime.now().millisecondsSinceEpoch;

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

  /// Whether a recorded server answered `/health` and is in the running phase.
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

  /// Seconds since the server started, when it is running.
  final int? uptimeSeconds;

  /// Exit code of the last finished process, when recorded.
  final int? lastExitCode;

  /// Failure recorded in the state document, when any.
  final ServerFailure? failure;

  /// Process exit code implied by the snapshot.
  int get exitCode => running ? 0 : 1;
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
  /// Returns true only when the state document records `starting` or
  /// `running` **and** `/health` answers. A stale state document returns false.
  Future<bool> recordedServerAnswers({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final state = await _stateRepository.load();
    if (state == null) {
      return false;
    }
    if (state.phase != ServerPhase.starting &&
        state.phase != ServerPhase.running) {
      return false;
    }
    final config = await _effectiveConfig(state);
    return _probe(config, timeout);
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

    final probeOk = state != null && state.isActive
        ? await _probe(config, timeout)
        : false;

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
    } else if (!probeOk) {
      status = 'stale';
      health = ServerHealth.unreachable.name;
    } else if (state.phase == ServerPhase.running) {
      status = ServerPhase.running.name;
      health = ServerHealth.ok.name;
    } else {
      status = state.phase.name;
      health = ServerHealth.ok.name;
    }
    final running = status == ServerPhase.running.name && probeOk;

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
      uptimeSeconds: running
          ? _uptimeSeconds(state.startedAtEpochMs, state.phase)
          : null,
      lastExitCode: state?.lastExitCode,
      failure: state?.failure,
    );
  }

  int? _uptimeSeconds(int? startedAtEpochMs, ServerPhase phase) {
    if (startedAtEpochMs == null || phase != ServerPhase.running) {
      return null;
    }
    final elapsed = _clock() - startedAtEpochMs;
    return elapsed < 0 ? 0 : elapsed ~/ 1000;
  }

  Future<bool> _probe(ServerConfig config, Duration timeout) async {
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
    return probe.ok;
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
