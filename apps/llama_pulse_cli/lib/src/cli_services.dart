import 'dart:async';
import 'dart:io' as io;

import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Dependencies shared by every CLI command.
///
/// Constructed in `bin/llamapulse.dart` for production and directly in tests
/// with an [InMemoryConfigStore] and [StringBuffer] sinks.
final class CliServices {
  /// Creates services over the supplied paths, store and sinks.
  ///
  /// [interrupts] is the SIGINT source; a null stream disables signal
  /// handling. [watchInterrupts] lazily wires the production signal only when
  /// a command actually reads [interrupts].
  CliServices({
    required this.paths,
    required this.configStore,
    required this.out,
    required this.err,
    this.stdin,
    Stream<io.ProcessSignal>? interrupts,
    LlamaEngine Function()? engineFactory,
    this.serverControllerFactory,
    bool? useStubServer,
    this.processSignaller = const DartProcessSignaller(),
    this.stopTimeout = const Duration(seconds: 10),
    this.stopPollInterval = const Duration(milliseconds: 200),
    bool watchInterrupts = false,
  }) : _interrupts = interrupts, // ignore: prefer_initializing_formals
       _engineFactory = engineFactory, // ignore: prefer_initializing_formals
       _useStubServer = useStubServer, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _watchInterrupts = watchInterrupts;

  /// Creates services rooted at the platform configuration directory.
  factory CliServices.production() {
    final paths = AppPaths.resolve();
    return CliServices(
      paths: paths,
      configStore: YamlFileConfigStore(directory: paths.configDirectory),
      out: io.stdout,
      err: io.stderr,
      stdin: io.stdin,
      watchInterrupts: !io.Platform.isWindows,
    );
  }

  /// Resolved configuration paths.
  final AppPaths paths;

  /// Persistence for the configuration documents.
  final ConfigStore configStore;

  /// Sink for regular command output.
  final StringSink out;

  /// Sink for errors, warnings and usage failures.
  final StringSink err;

  /// Raw byte source for `--file -`; null when the command has no stdin.
  final Stream<List<int>>? stdin;

  final Stream<io.ProcessSignal>? _interrupts;
  final LlamaEngine Function()? _engineFactory;
  final bool? _useStubServer;
  final bool _watchInterrupts;

  /// Overrides controller creation when set; an explicit factory always wins
  /// over [useStubServer] and production wiring.
  ServerController Function()? serverControllerFactory;

  /// Signals the recorded supervisor or server process during `stop`.
  final ProcessSignaller processSignaller;

  /// How long `stop` waits for a signalled process before forcing it.
  final Duration stopTimeout;

  /// Delay between liveness checks during `stop`.
  final Duration stopPollInterval;

  Stream<io.ProcessSignal>? _watchedInterrupts;
  YamlModelParamsRepository? _paramsRepository;
  YamlServerConfigRepository? _serverConfigRepository;
  YamlServerStateRepository? _serverStateRepository;
  ServerLogStore? _serverLogStore;
  ModelFileScanner? _scanner;

  /// SIGINT and SIGTERM source, created on first read when production
  /// watching is enabled.
  ///
  /// Both signals are merged into one stream so a command can react to either.
  /// The production wiring never watches signals on Windows.
  Stream<io.ProcessSignal>? get interrupts {
    if (_interrupts != null) {
      return _interrupts;
    }
    if (!_watchInterrupts) {
      return null;
    }
    return _watchedInterrupts ??= _watchInterruptSignals();
  }

  /// Creates the inference engine.
  ///
  /// An injected factory always wins. Otherwise this builds a
  /// [WorkerLlamaEngine], forwarding [useStubSession] so the caller decides
  /// whether the worker runs the deterministic stub or the unavailable native
  /// placeholder.
  LlamaEngine createEngine({bool useStubSession = false}) =>
      _engineFactory?.call() ??
      WorkerLlamaEngine(useStubSession: useStubSession);

  /// Loads and saves `params.yaml`; built once from [configStore].
  YamlModelParamsRepository get paramsRepository => _paramsRepository ??=
      YamlModelParamsRepository(store: configStore, serializers: serializers);

  /// Finds model files on disk.
  ModelFileScanner get scanner => _scanner ??= const ModelFileScanner();

  /// Loads and saves `server.yaml`; built once from [configStore].
  YamlServerConfigRepository get serverConfigRepository =>
      _serverConfigRepository ??= YamlServerConfigRepository(
        store: configStore,
        serializers: serializers,
      );

  /// Reads and writes `server-state.yaml`; built once from [configStore].
  YamlServerStateRepository get serverStateRepository =>
      _serverStateRepository ??= YamlServerStateRepository(
        store: configStore,
        serializers: serializers,
      );

  /// The append-only log at [AppPaths.serverLogFile].
  ServerLogStore get serverLogStore =>
      _serverLogStore ??= ServerLogStore(filePath: paths.serverLogFile);

  /// Whether the demo stub controller replaces the production supervisor.
  ///
  /// Read from `LLAMAPULSE_STUB_SERVER=true` unless the constructor set it.
  /// Production never falls back to the stub on its own.
  bool get useStubServer =>
      _useStubServer ??
      io.Platform.environment['LLAMAPULSE_STUB_SERVER'] == 'true';

  /// Creates the server controller for one command.
  ///
  /// An explicit [serverControllerFactory] wins; otherwise [useStubServer]
  /// selects [StubServerController], and the production supervisor is the
  /// default.
  ServerController createServerController() {
    final factory = serverControllerFactory;
    if (factory != null) {
      return factory();
    }
    if (useStubServer) {
      return StubServerController(stateRepository: serverStateRepository);
    }
    return LlamaServerSupervisor.production(
      paths: paths,
      configStore: configStore,
    );
  }

  Stream<io.ProcessSignal> _watchInterruptSignals() {
    final controller = StreamController<io.ProcessSignal>();
    final subscriptions = <StreamSubscription<io.ProcessSignal>>[];
    void listen(io.ProcessSignal signal) {
      subscriptions.add(
        signal.watch().listen(controller.add, onError: controller.addError),
      );
    }

    controller.onListen = () {
      listen(io.ProcessSignal.sigint);
      if (!io.Platform.isWindows) {
        listen(io.ProcessSignal.sigterm);
      }
    };
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      subscriptions.clear();
    };
    return controller.stream;
  }
}
