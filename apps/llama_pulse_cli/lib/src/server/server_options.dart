import 'package:args/args.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Registers the server configuration flags shared by `server set` and
/// `serve`.
///
/// `--model` is accepted as an alias of `--model-path`. `--mlock` and `--mmap`
/// are negatable; omitting one leaves the stored value untouched.
void addServerOptionFlags(ArgParser parser, {bool includeReset = false}) {
  parser
    ..addOption('model-path', help: 'Path to the .gguf model file.')
    ..addOption('model', help: 'Alias of --model-path.')
    ..addOption('host', help: 'Address llama-server binds to.')
    ..addOption('port', help: 'TCP port llama-server listens on.')
    ..addOption('context-size', help: 'Context window, in tokens.')
    ..addOption('threads', help: 'Worker threads used for evaluation.')
    ..addOption('gpu-layers', help: 'Layers offloaded to the GPU.')
    ..addOption('parallel', help: 'Number of parallel request slots.')
    ..addOption('alias', help: 'Model name clients pass in requests.')
    ..addOption('api-key', help: 'Bearer token clients must send.')
    ..addOption('flash-attn', help: 'Flash-attention mode: on, off or auto.')
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
}

/// The parsed shared server flags.
final class ParsedServerOptions {
  /// Creates a parse result; [errors] is empty when every value parsed.
  const ParsedServerOptions({
    required this.overrides,
    required this.errors,
    required this.json,
    this.reset = false,
  });

  /// The accepted overrides.
  final ServerOptionOverrides overrides;

  /// One message per flag whose value was not usable.
  final List<String> errors;

  /// Whether `--json` was supplied.
  final bool json;

  /// Whether `--reset` was supplied; always false when the flag is absent.
  final bool reset;
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
    json: args.flag('json'),
    reset: includeReset && args.flag('reset'),
  );
}
