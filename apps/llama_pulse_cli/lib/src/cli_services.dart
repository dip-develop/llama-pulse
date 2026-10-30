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
    bool watchInterrupts = false,
  }) : _interrupts = interrupts, // ignore: prefer_initializing_formals
       _engineFactory = engineFactory, // ignore: prefer_initializing_formals
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
  final bool _watchInterrupts;

  Stream<io.ProcessSignal>? _watchedInterrupts;
  YamlModelParamsRepository? _paramsRepository;
  ModelFileScanner? _scanner;

  /// SIGINT source, created on first read when production watching is enabled.
  Stream<io.ProcessSignal>? get interrupts {
    if (_interrupts != null) {
      return _interrupts;
    }
    if (!_watchInterrupts) {
      return null;
    }
    return _watchedInterrupts ??= io.ProcessSignal.sigint.watch();
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
}
