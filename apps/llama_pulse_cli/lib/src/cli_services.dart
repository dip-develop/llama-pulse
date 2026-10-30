import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Dependencies shared by every CLI command.
///
/// Constructed in `bin/llamapulse.dart` for production and directly in tests
/// with an [InMemoryConfigStore] and [StringBuffer] sinks.
final class CliServices {
  /// Creates services over the supplied paths, store and sinks.
  CliServices({
    required this.paths,
    required this.configStore,
    required this.out,
    required this.err,
  });

  /// Creates services rooted at the platform configuration directory.
  factory CliServices.production() {
    final paths = AppPaths.resolve();
    return CliServices(
      paths: paths,
      configStore: YamlFileConfigStore(directory: paths.configDirectory),
      out: stdout,
      err: stderr,
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

  YamlModelParamsRepository? _paramsRepository;
  ModelFileScanner? _scanner;

  /// Loads and saves `params.yaml`; built once from [configStore].
  YamlModelParamsRepository get paramsRepository => _paramsRepository ??=
      YamlModelParamsRepository(store: configStore, serializers: serializers);

  /// Finds model files on disk.
  ModelFileScanner get scanner => _scanner ??= const ModelFileScanner();
}
