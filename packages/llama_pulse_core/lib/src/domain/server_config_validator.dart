import 'entities/server_config.dart';

/// Validates [ServerConfig] before it is stored or used to start a server.
final class ServerConfigValidator {
  const ServerConfigValidator();

  /// Flags `llama-server` already receives from a managed config field.
  ///
  /// Repeating one in [ServerConfig.extraArgs] would make the effective launch
  /// ambiguous, so such items are rejected. Matching is by exact token: a
  /// combined form such as `-m=/models/x.gguf` is not detected and passes.
  static const Set<String> managedFlags = {
    '-m',
    '--model',
    '--host',
    '--port',
    '-c',
    '--ctx-size',
    '-t',
    '--threads',
    '-ngl',
    '--gpu-layers',
    '-np',
    '--parallel',
    '-a',
    '--alias',
    '--api-key',
    '-fa',
    '--flash-attn',
    '--metrics',
    '--slots',
    '--no-slots',
    '-lm',
    '--load-mode',
    '--mlock',
    '--no-mlock',
    '--mmap',
    '--no-mmap',
    '--',
  };

  /// Returns one message per violated field, in field declaration order.
  ///
  /// An empty list means the value is valid. An empty
  /// [ServerConfig.modelPath] is accepted as "not configured"; use
  /// [validateForStart] when the configuration is about to launch a server.
  List<String> validate(ServerConfig config) {
    final violations = <String>[];

    if (config.modelPath.isNotEmpty && config.modelPath.trim().isEmpty) {
      violations.add('modelPath must not be blank');
    }

    final host = config.host;
    if (host.isEmpty) {
      violations.add('host must be set');
    } else if (host.length > 255) {
      violations.add('host must be at most 255 characters');
    } else if (_whitespace.hasMatch(host)) {
      violations.add('host must not contain whitespace');
    } else if (host.contains('/')) {
      violations.add('host must not contain /');
    }

    _checkInt(violations, 'port', config.port, 1, 65535);
    _checkInt(violations, 'contextSize', config.contextSize, 128, 1048576);
    _checkInt(violations, 'threads', config.threads, 1, 256);
    _checkInt(violations, 'gpuLayers', config.gpuLayers, 0, 999);
    _checkInt(violations, 'parallelSlots', config.parallelSlots, 1, 64);

    if (config.modelAlias.length > 128) {
      violations.add('modelAlias must be at most 128 characters');
    }
    if (_hasControlChar(config.modelAlias)) {
      violations.add('modelAlias must not contain control characters');
    }

    if (config.apiKey.length > 4096) {
      violations.add('apiKey must be at most 4096 characters');
    }
    if (config.apiKey.contains('\n') || config.apiKey.contains('\r')) {
      violations.add('apiKey must not contain line breaks');
    }

    final extraArgs = config.extraArgs;
    if (extraArgs.length > 64) {
      violations.add('extraArgs must contain at most 64 items');
    }
    if (extraArgs.any((arg) => arg.isEmpty || arg.length > 1024)) {
      violations.add('extraArgs must contain 1..1024 characters per item');
    }
    if (extraArgs.any(_hasControlChar)) {
      violations.add('extraArgs must not contain control characters');
    }
    for (final arg in extraArgs) {
      if (managedFlags.contains(arg)) {
        violations.add('extraArgs must not repeat the managed flag $arg');
        break;
      }
    }

    if (_hasControlChar(config.binaryPath)) {
      violations.add('binaryPath must not contain control characters');
    }

    _checkInt(
      violations,
      'startupTimeoutSeconds',
      config.startupTimeoutSeconds,
      10,
      600,
    );

    return violations;
  }

  /// Returns [validate] plus the requirements that only matter when starting.
  ///
  /// A server cannot launch without a `.gguf` model, so a blank path is
  /// `modelPath must be set` and anything else is rejected unless it ends in
  /// `.gguf` (case-insensitive).
  List<String> validateForStart(ServerConfig config) {
    final violations = validate(config).toList();
    if (config.modelPath.isEmpty) {
      violations.add('modelPath must be set');
    } else if (!config.modelPath.toLowerCase().endsWith('.gguf')) {
      violations.add('modelPath must point to a .gguf file');
    }
    return violations;
  }

  static final RegExp _whitespace = RegExp(r'\s');

  static bool _hasControlChar(String value) {
    for (final rune in value.runes) {
      if (rune < 0x20 || (rune >= 0x7f && rune <= 0x9f)) {
        return true;
      }
    }
    return false;
  }

  void _checkInt(
    List<String> violations,
    String field,
    int value,
    int min,
    int max,
  ) {
    if (value < min || value > max) {
      violations.add('$field must be in $min..$max');
    }
  }
}
