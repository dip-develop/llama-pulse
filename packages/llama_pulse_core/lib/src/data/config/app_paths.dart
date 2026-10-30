import 'dart:io';

import 'package:path/path.dart' as p;

/// Locations of the files LlamaPulse reads and writes.
final class AppPaths {
  /// Creates paths rooted at [configDirectory].
  const AppPaths({required this.configDirectory});

  /// Resolves the platform's configuration directory.
  ///
  /// [environment] and [operatingSystem] default to the current process values
  /// and are injectable for tests; when both are supplied, `Platform` is never
  /// queried. `LLAMA_PULSE_CONFIG_DIR` wins when it is absolute. Otherwise the
  /// directory follows the XDG, macOS or Windows convention for
  /// [operatingSystem]. Throws [StateError] when a required variable is absent.
  factory AppPaths.resolve({
    Map<String, String>? environment,
    String? operatingSystem,
  }) {
    final env = environment ?? Platform.environment;
    final os = operatingSystem ?? Platform.operatingSystem;

    final override = env['LLAMA_PULSE_CONFIG_DIR'];
    if (override != null && override.isNotEmpty && p.isAbsolute(override)) {
      return AppPaths(configDirectory: override);
    }

    final directory = switch (os) {
      'macos' => _macOs(env),
      'windows' => _windows(env),
      _ => _posix(env),
    };
    return AppPaths(configDirectory: directory);
  }

  /// Absolute directory holding the user's configuration files.
  final String configDirectory;

  /// The YAML file holding startup parameters.
  String get paramsYamlFile => p.join(configDirectory, 'params.yaml');

  /// Directory holding locally available model files.
  String get modelsDirectory => p.join(configDirectory, 'models');

  static String _posix(Map<String, String> env) {
    final xdg = env['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty && p.isAbsolute(xdg)) {
      return p.join(xdg, 'llamapulse');
    }
    return p.join(_require(env, 'HOME'), '.config', 'llamapulse');
  }

  static String _macOs(Map<String, String> env) {
    final home = _require(env, 'HOME');
    return p.join(home, 'Library', 'Application Support', 'LlamaPulse');
  }

  static String _windows(Map<String, String> env) {
    final appData = env['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return p.join(appData, 'LlamaPulse');
    }
    final profile = _require(env, 'USERPROFILE');
    return p.join(profile, 'AppData', 'Roaming', 'LlamaPulse');
  }

  static String _require(Map<String, String> env, String name) {
    final value = env[name];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Cannot resolve the configuration directory: $name is not set. '
        'Set $name or LLAMA_PULSE_CONFIG_DIR.',
      );
    }
    return value;
  }
}
