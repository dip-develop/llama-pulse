import '../../domain/entities/server_config.dart';

/// Builds the `llama-server` argument vector for a [ServerConfig].
final class ServerArgumentBuilder {
  /// Creates a builder.
  const ServerArgumentBuilder();

  /// Returns the raw argument tokens for [config].
  ///
  /// [useLoadMode] selects the modern `-lm` flag; otherwise the legacy
  /// `--mlock` / `--no-mmap` pair is emitted. Tokens are passed to the
  /// launcher as an argument vector, so they are never shell-quoted.
  List<String> build(ServerConfig config, {required bool useLoadMode}) {
    final arguments = <String>[
      '-m',
      config.modelPath,
      '--host',
      config.host,
      '--port',
      '${config.port}',
      '-c',
      '${config.contextSize}',
      '-t',
      '${config.threads}',
      '-ngl',
      '${config.gpuLayers}',
      '-np',
      '${config.parallelSlots}',
      '-fa',
      config.flashAttention.name,
      '--metrics',
      '--slots',
    ];

    if (config.modelAlias.isNotEmpty) {
      arguments.addAll(['-a', config.modelAlias]);
    }
    if (config.apiKey.isNotEmpty) {
      arguments.addAll(['--api-key', config.apiKey]);
    }

    if (useLoadMode) {
      arguments.addAll(['-lm', _loadMode(config)]);
    } else {
      if (config.mlock) {
        arguments.add('--mlock');
      }
      if (!config.mmap) {
        arguments.add('--no-mmap');
      }
    }

    arguments.addAll(config.extraArgs);
    return arguments;
  }

  static String _loadMode(ServerConfig config) =>
      switch ((config.mmap, config.mlock)) {
        (true, false) => 'mmap',
        (true, true) => 'mmap+mlock',
        (false, true) => 'mlock',
        (false, false) => 'none',
      };
}
