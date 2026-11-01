import 'package:args/args.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Registers the server configuration flags shared by `server set` and
/// `serve`.
///
/// `--model` is accepted as an alias of `--model-path`. `--mlock` and `--mmap`
/// are negatable; omitting one leaves the stored value untouched. Every typed
/// flag with a catalog entry takes its help text from the generated catalog, so
/// `--help` and `params describe` cannot drift apart.
void addServerOptionFlags(ArgParser parser, {bool includeReset = false}) {
  parser
    ..addOption(
      'model-path',
      help: _catalogHelp('model', 'Path to the .gguf model file.'),
    )
    ..addOption('model', help: 'Alias of --model-path.')
    ..addOption('host', help: _catalogHelp('host', 'Address to bind.'))
    ..addOption('port', help: _catalogHelp('port', 'TCP port to listen on.'))
    ..addOption(
      'context-size',
      help: _catalogHelp('ctx-size', 'Context window, in tokens.'),
    )
    ..addOption(
      'threads',
      help: _catalogHelp('threads', 'Worker threads used for evaluation.'),
    )
    ..addOption(
      'gpu-layers',
      help: _catalogHelp('gpu-layers', 'Layers offloaded to the GPU.'),
    )
    ..addOption(
      'parallel',
      help: _catalogHelp('parallel', 'Number of parallel request slots.'),
    )
    ..addOption(
      'alias',
      help: _catalogHelp('alias', 'Model name clients pass in requests.'),
    )
    ..addOption(
      'api-key',
      help: _catalogHelp('api-key', 'Bearer token clients must send.'),
    )
    ..addOption(
      'flash-attn',
      help:
          '${_catalogHelp('flash-attn', 'Flash-attention mode')} '
          'on, off or auto.',
    )
    ..addFlag(
      'mlock',
      negatable: true,
      defaultsTo: null,
      help: 'Lock the model in RAM (--no-mlock clears it).',
    )
    ..addFlag(
      'mmap',
      negatable: true,
      defaultsTo: null,
      help: 'Memory-map the model (--no-mmap clears it).',
    )
    ..addMultiOption(
      'extra-arg',
      splitCommas: false,
      help:
          'Extra llama-server argument; repeatable, replaces the stored '
          'list.',
    )
    ..addMultiOption(
      'param',
      splitCommas: false,
      valueHelp: 'id|id=value',
      help:
          'Set a catalog parameter. `id=value` sets it, `id=` removes it and '
          'a bare `id` sets a boolean to true. Repeatable; a repeatable '
          'parameter keeps every value. See `llamapulse params catalog` and '
          '`llamapulse params describe <id>`.',
    )
    ..addOption('binary', help: 'Path to the llama-server executable.')
    ..addOption('startup-timeout', help: 'Seconds to wait for readiness.')
    ..addFlag(
      'json',
      negatable: false,
      help: 'Print machine-readable JSON instead of YAML or text.',
    );
  if (includeReset) {
    parser.addFlag(
      'reset',
      negatable: false,
      help: 'Restore the default server configuration instead of updating it.',
    );
  }
}

/// Returns the catalog summary for [id], or [fallback] when it is absent.
String _catalogHelp(String id, String fallback) =>
    ParameterCatalog.v080.byId(id)?.summary ?? fallback;

/// Spelling of the typed flag that writes [id]; used in conflict messages.
const Map<String, String> _typedFlagNames = {
  'model': '--model-path',
  'host': '--host',
  'port': '--port',
  'ctx-size': '--context-size',
  'threads': '--threads',
  'gpu-layers': '--gpu-layers',
  'parallel': '--parallel',
  'alias': '--alias',
  'api-key': '--api-key',
  'flash-attn': '--flash-attn',
  'extra-args': '--extra-arg',
};

/// Values parsed from the shared server flags; null means "not supplied".
final class ServerOptionOverrides {
  /// Creates overrides.
  const ServerOptionOverrides({
    this.modelPath,
    this.host,
    this.port,
    this.contextSize,
    this.threads,
    this.gpuLayers,
    this.parallelSlots,
    this.modelAlias,
    this.apiKey,
    this.flashAttention,
    this.mlock,
    this.mmap,
    this.extraArgs,
    this.binaryPath,
    this.startupTimeoutSeconds,
  });

  /// Model file path.
  final String? modelPath;

  /// Bind address.
  final String? host;

  /// TCP port.
  final int? port;

  /// Context window.
  final int? contextSize;

  /// Worker threads.
  final int? threads;

  /// GPU layers.
  final int? gpuLayers;

  /// Parallel slots.
  final int? parallelSlots;

  /// Model alias.
  final String? modelAlias;

  /// Bearer token.
  final String? apiKey;

  /// Flash-attention mode.
  final ServerFlashAttention? flashAttention;

  /// Whether the model is locked in RAM.
  final bool? mlock;

  /// Whether the model is memory-mapped.
  final bool? mmap;

  /// Replacement extra arguments; null leaves the stored list untouched.
  final List<String>? extraArgs;

  /// Executable path.
  final String? binaryPath;

  /// Startup timeout in seconds.
  final int? startupTimeoutSeconds;

  /// Whether at least one value flag was supplied.
  bool get hasAny =>
      modelPath != null ||
      host != null ||
      port != null ||
      contextSize != null ||
      threads != null ||
      gpuLayers != null ||
      parallelSlots != null ||
      modelAlias != null ||
      apiKey != null ||
      flashAttention != null ||
      mlock != null ||
      mmap != null ||
      extraArgs != null ||
      binaryPath != null ||
      startupTimeoutSeconds != null;

  /// Returns [config] with every supplied value applied.
  ServerConfig applyTo(ServerConfig config) {
    var next = config.copyWith(
      modelPath: modelPath,
      host: host,
      port: port,
      contextSize: contextSize,
      threads: threads,
      gpuLayers: gpuLayers,
      parallelSlots: parallelSlots,
      modelAlias: modelAlias,
      apiKey: apiKey,
      flashAttention: flashAttention,
      mlock: mlock,
      mmap: mmap,
      binaryPath: binaryPath,
      startupTimeoutSeconds: startupTimeoutSeconds,
    );
    final args = extraArgs;
    if (args != null) {
      next = next.rebuild((b) => b..extraArgs.replace(args));
    }
    return next;
  }

  /// Canonical value of the typed flag that owns [id], or `null`.
  ///
  /// The value is already canonical: integers are decimal, the flash-attention
  /// mode uses its enum name and the extra arguments are newline-separated, the
  /// same form [ParameterValueCodec] produces for a `--param` value.
  String? typedValueFor(String id) => switch (id) {
    'model' => modelPath,
    'host' => host,
    'port' => port?.toString(),
    'ctx-size' => contextSize?.toString(),
    'threads' => threads?.toString(),
    'gpu-layers' => gpuLayers?.toString(),
    'parallel' => parallelSlots?.toString(),
    'alias' => modelAlias,
    'api-key' => apiKey,
    'flash-attn' => flashAttention?.name,
    'extra-args' => extraArgs?.join('\n'),
    _ => null,
  };
}

/// The parsed shared server flags.
final class ParsedServerOptions {
  /// Creates a parse result; [errors] is empty when every value parsed.
  const ParsedServerOptions({
    required this.overrides,
    required this.errors,
    required this.json,
    this.paramOverrides = const {},
    this.paramErrors = const [],
    this.reset = false,
  });

  /// The accepted overrides.
  final ServerOptionOverrides overrides;

  /// One message per flag whose value was not usable.
  final List<String> errors;

  /// Catalog values supplied with `--param`, keyed by catalog id.
  ///
  /// An empty value means "remove the stored value". A repeatable parameter
  /// keeps its occurrences newline-separated.
  final Map<String, String> paramOverrides;

  /// One message per `--param` argument that could not be parsed.
  final List<String> paramErrors;

  /// Whether `--json` was supplied.
  final bool json;

  /// Whether `--reset` was supplied; always false when the flag is absent.
  final bool reset;

  /// Whether any `--param` argument was supplied, valid or not.
  bool get hasParamOverrides => paramOverrides.isNotEmpty;
}

/// Parses the shared server flags, collecting invalid values.
///
/// Set [includeReset] only when the parser registered `--reset`.
ParsedServerOptions parseServerOptions(
  ArgResults args, {
  bool includeReset = false,
}) {
  final errors = <String>[];

  int? readInt(String name) {
    final raw = args.option(name);
    if (raw == null) {
      return null;
    }
    final value = int.tryParse(raw);
    if (value == null) {
      errors.add("invalid value for --$name: '$raw'");
    }
    return value;
  }

  String? readModelPath() {
    final canonical = args.option('model-path');
    final alias = args.option('model');
    if (canonical != null && alias != null && canonical != alias) {
      errors.add('--model and --model-path cannot both be different values');
      return canonical;
    }
    return canonical ?? alias;
  }

  ServerFlashAttention? flashAttention;
  final rawFlash = args.option('flash-attn');
  if (rawFlash != null) {
    try {
      flashAttention = ServerFlashAttention.valueOf(rawFlash);
    } on ArgumentError {
      errors.add("invalid value for --flash-attn: '$rawFlash'");
    }
  }

  bool? readFlag(String name) => args.wasParsed(name) ? args.flag(name) : null;

  final paramErrors = <String>[];
  final paramOverrides = <String, String>{};
  final rawParams = args.wasParsed('param')
      ? args.multiOption('param')
      : const <String>[];
  for (final raw in rawParams) {
    final equals = raw.indexOf('=');
    final id = (equals < 0 ? raw : raw.substring(0, equals)).trim();
    if (id.isEmpty) {
      paramErrors.add("invalid value for --param: '$raw' (expected id=value)");
      continue;
    }

    final spec = ParameterCatalog.v080.byId(id);
    String value;
    if (equals < 0) {
      if (spec != null && spec.type != ParamValueType.bool) {
        paramErrors.add(
          "invalid value for --param: '$id' is not a boolean; use $id=value",
        );
        continue;
      }
      value = 'true';
    } else {
      value = raw.substring(equals + 1);
    }

    final current = paramOverrides[id];
    if (spec != null &&
        spec.repeatable &&
        value.isNotEmpty &&
        current != null) {
      paramOverrides[id] = current.isEmpty ? value : '$current\n$value';
    } else {
      paramOverrides[id] = value;
    }
  }

  return ParsedServerOptions(
    overrides: ServerOptionOverrides(
      modelPath: readModelPath(),
      host: args.option('host'),
      port: readInt('port'),
      contextSize: readInt('context-size'),
      threads: readInt('threads'),
      gpuLayers: readInt('gpu-layers'),
      parallelSlots: readInt('parallel'),
      modelAlias: args.option('alias'),
      apiKey: args.option('api-key'),
      flashAttention: flashAttention,
      mlock: readFlag('mlock'),
      mmap: readFlag('mmap'),
      extraArgs: args.wasParsed('extra-arg')
          ? List<String>.of(args.multiOption('extra-arg'))
          : null,
      binaryPath: args.option('binary'),
      startupTimeoutSeconds: readInt('startup-timeout'),
    ),
    errors: errors,
    paramOverrides: paramOverrides,
    paramErrors: paramErrors,
    json: args.flag('json'),
    reset: includeReset && args.flag('reset'),
  );
}

/// The result of applying typed flags and `--param` values to a configuration.
final class ResolvedServerConfig {
  /// Creates a resolution result; [errors] is empty when every value applied.
  const ResolvedServerConfig({required this.config, required this.errors});

  /// The resulting configuration. With errors it is only a preview and must
  /// not be persisted.
  final ServerConfig config;

  /// One message per rejected `--param` value.
  final List<String> errors;
}

/// Applies [overrides] and then [paramOverrides] to [config].
///
/// Typed flags are applied first. A `--param` id whose catalog entry has an
/// [ParameterSpec.owner] writes that typed field instead of
/// [ServerConfig.params]: `--param threads=8` stores `threads: 8`, never a
/// `params` entry. Such an id is accepted even though the catalog marks it
/// managed, because the typed field is the one place LlamaPulse reads it from.
/// When the matching typed flag was also supplied the two values must agree;
/// otherwise the conflict is reported and nothing is applied.
///
/// Every other id goes through [ParameterValidator], so managed ids without a
/// typed field, unsupported and removed entries, wrong-surface ids and invalid
/// values are all reported with the validator's wording. A `--param` argument
/// is never saved by this function; callers decide what to do with [config].
ResolvedServerConfig resolveServerConfig({
  required ServerConfig config,
  required ServerOptionOverrides overrides,
  required Map<String, String> paramOverrides,
  required bool forStart,
  bool Function(String path)? pathExists,
}) {
  final catalog = ParameterCatalog.v080;
  final errors = <String>[];
  var next = overrides.applyTo(config);

  // Validate every map-backed value in one pass so the messages follow catalog
  // order, exactly as they would when the values were already stored.
  var probe = next.params;
  for (final entry in paramOverrides.entries) {
    final spec = catalog.byId(entry.key);
    if (spec != null) {
      if (spec.owner != null) {
        continue;
      }
      // An empty value removes a stored value; that is only valid for a
      // configurable parameter. Managed, unsupported and removed ids still go
      // through the validator so they keep their documented message.
      if (entry.value.isEmpty && spec.exposure == ParamExposure.configurable) {
        continue;
      }
    }
    probe = ParameterValues.set(probe, entry.key, entry.value);
  }
  final problems = ParameterValidator(pathExists: pathExists)
      .validateValues(probe, surface: ParamSurface.server, forStart: forStart);
  errors.addAll(problems);

  final mapValues = <String, String?>{};
  for (final entry in paramOverrides.entries) {
    final id = entry.key;
    final raw = entry.value;
    final spec = catalog.byId(id);
    if (spec == null) {
      // The validator reports unknown ids; nothing to canonicalize.
      continue;
    }

    if (spec.owner != null) {
      final owner = spec.owner!;
      final typed = overrides.typedValueFor(id);
      if (raw.isEmpty) {
        // Removing an owned value restores the typed default, unless the typed
        // flag already supplied a value for this run.
        if (typed == null) {
          next = _applyOwnedDefault(next, owner, spec);
        }
        continue;
      }

      final valueProblems = ParameterValueCodec.validate(
        spec,
        raw,
        forStart: forStart,
        pathExists: pathExists,
      );
      if (valueProblems.isNotEmpty) {
        errors.addAll(valueProblems);
        continue;
      }
      final canonical = ParameterValueCodec.parse(spec, raw);
      if (canonical == null) {
        continue;
      }
      if (typed != null) {
        if (typed != canonical) {
          errors.add(
            '${_typedFlagNames[id] ?? '--$id'} and --param $id disagree '
            '($typed vs $canonical)',
          );
        }
        // Equal values are already stored through the typed field.
        continue;
      }
      final applied = _applyOwned(next, owner, canonical);
      if (applied.error != null) {
        errors.add(applied.error!);
      } else {
        next = applied.config!;
        // A hand-edited document may still carry the id in the map; the typed
        // field is authoritative, so the stale entry is dropped.
        next = next.copyWith(params: ParameterValues.remove(next.params, id));
      }
      continue;
    }

    if (raw.isEmpty) {
      mapValues[id] = null;
      continue;
    }
    final String? canonical;
    try {
      canonical = ParameterValueCodec.parse(spec, raw);
    } on FormatException {
      // `validateValues` already reported the reason.
      continue;
    }
    if (canonical != null) {
      mapValues[id] = canonical;
    }
  }

  if (errors.isEmpty) {
    var params = next.params;
    for (final entry in mapValues.entries) {
      params = ParameterValues.set(params, entry.key, entry.value);
    }
    next = next.copyWith(params: params);
  }

  return ResolvedServerConfig(config: next, errors: errors);
}

typedef _Applied = ({ServerConfig? config, String? error});

/// Writes [canonical] into the [ServerConfig] field named by [owner].
_Applied _applyOwned(ServerConfig config, String owner, String canonical) {
  switch (owner) {
    case 'modelPath':
      return (config: config.copyWith(modelPath: canonical), error: null);
    case 'host':
      return (config: config.copyWith(host: canonical), error: null);
    case 'port':
      final value = int.tryParse(canonical);
      return value == null
          ? (config: null, error: "--port must be an integer: '$canonical'")
          : (config: config.copyWith(port: value), error: null);
    case 'contextSize':
      final value = int.tryParse(canonical);
      return value == null
          ? (
              config: null,
              error: "--context-size must be an integer: '$canonical'",
            )
          : (config: config.copyWith(contextSize: value), error: null);
    case 'threads':
      final value = int.tryParse(canonical);
      return value == null
          ? (config: null, error: "--threads must be an integer: '$canonical'")
          : (config: config.copyWith(threads: value), error: null);
    case 'gpuLayers':
      final value = int.tryParse(canonical);
      return value == null
          ? (
              config: null,
              error: "--gpu-layers must be an integer: '$canonical'",
            )
          : (config: config.copyWith(gpuLayers: value), error: null);
    case 'parallelSlots':
      final value = int.tryParse(canonical);
      return value == null
          ? (config: null, error: "--parallel must be an integer: '$canonical'")
          : (config: config.copyWith(parallelSlots: value), error: null);
    case 'modelAlias':
      return (config: config.copyWith(modelAlias: canonical), error: null);
    case 'apiKey':
      return (config: config.copyWith(apiKey: canonical), error: null);
    case 'flashAttention':
      try {
        return (
          config: config.copyWith(
            flashAttention: ServerFlashAttention.valueOf(canonical),
          ),
          error: null,
        );
      } on ArgumentError {
        return (
          config: null,
          error: "--flash-attn must be one of: on, off, auto",
        );
      }
    case 'extraArgs':
      final items = canonical.isEmpty
          ? const <String>[]
          : canonical.split('\n');
      return (
        config: config.rebuild((b) => b..extraArgs.replace(items)),
        error: null,
      );
    default:
      return (config: null, error: "'$owner' has no server field");
  }
}

/// Restores the typed default of [owner] for the parameter [spec].
ServerConfig _applyOwnedDefault(
  ServerConfig config,
  String owner,
  ParameterSpec spec,
) {
  final defaults = ServerConfig.defaults();
  final value = ParameterValues.valueFor(defaults, spec.id) ?? '';
  final applied = _applyOwned(config, owner, value);
  return applied.config ?? config;
}
