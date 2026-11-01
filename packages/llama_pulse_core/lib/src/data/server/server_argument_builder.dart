import '../../domain/entities/parameter_spec.dart';
import '../../domain/entities/server_config.dart';
import '../../domain/parameters/parameter_catalog.dart';
import '../../domain/parameters/parameter_value_codec.dart';

/// Builds the `llama-server` argument vector for a [ServerConfig].
final class ServerArgumentBuilder {
  /// Creates a builder.
  ///
  /// [catalog] supplies the declaration order and the flag spelling of the
  /// generic parameters stored in [ServerConfig.params]. [onWarning] receives
  /// one message per configured value that cannot be expressed as arguments;
  /// without a sink such values are skipped silently.
  const ServerArgumentBuilder({
    this.catalog = ParameterCatalog.v080,
    this.onWarning,
  });

  /// Catalog that describes the generic parameters.
  final ParameterCatalog catalog;

  /// Receives a message for every configured value that cannot be emitted.
  final void Function(String message)? onWarning;

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

    _appendParameters(arguments, config);

    arguments.addAll(config.extraArgs);
    return arguments;
  }

  /// Appends [ServerConfig.params] in catalog order.
  ///
  /// Iterating the catalog, not the map, keeps the vector independent of the
  /// map's insertion order. Values with a typed owner are already part of the
  /// block above, and managed, unsupported and removed parameters never reach
  /// the command line; the validator rejects them, and skipping them here keeps
  /// a hand-edited document from launching an ambiguous server.
  void _appendParameters(List<String> arguments, ServerConfig config) {
    for (final spec in catalog.parameters) {
      final raw = config.params[spec.id];
      if (raw == null) {
        continue;
      }
      if (spec.owner != null ||
          spec.exposure != ParamExposure.configurable ||
          !spec.appliesTo(ParamSurface.server) ||
          spec.flags.isEmpty) {
        continue;
      }

      final value = _parse(spec, raw);
      if (value == null) {
        continue;
      }
      final flag = _preferredFlag(spec);

      if (spec.type == ParamValueType.bool && spec.arity == 0) {
        switch (value) {
          case 'true':
            arguments.add(flag);
          case 'false':
            final negated = spec.negatedFlag;
            if (negated == null) {
              _warn("'${spec.id}' is false and $flag has no negated form");
            } else {
              arguments.add(negated);
            }
        }
        continue;
      }

      if (spec.arity == 2) {
        arguments.addAll([flag, ...value.split('\n')]);
        continue;
      }

      if (spec.repeatable) {
        for (final item in value.split('\n')) {
          arguments.addAll([flag, item]);
        }
        continue;
      }

      arguments.addAll([flag, value]);
    }
  }

  /// Returns the canonical form of [raw], or `null` when it means "not set".
  ///
  /// The validator is the normal gate, so an invalid stored value is a
  /// programming or document error; failing here beats emitting garbage.
  String? _parse(ParameterSpec spec, String raw) {
    try {
      return ParameterValueCodec.parse(spec, raw);
    } on FormatException catch (error) {
      throw ArgumentError.value(raw, spec.id, error.message);
    }
  }

  /// Returns the long form of the parameter when it has one.
  ///
  /// Upstream declares short aliases first (`-cb`, `--cont-batching`); the long
  /// form keeps the child process command line readable and unambiguous.
  static String _preferredFlag(ParameterSpec spec) => spec.flags.firstWhere(
    (flag) => flag.startsWith('--'),
    orElse: () => spec.flags.first,
  );

  void _warn(String message) => onWarning?.call(message);

  static String _loadMode(ServerConfig config) =>
      switch ((config.mmap, config.mlock)) {
        (true, false) => 'mmap',
        (true, true) => 'mmap+mlock',
        (false, true) => 'mlock',
        (false, false) => 'none',
      };
}
