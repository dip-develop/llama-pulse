import 'dart:io';

/// Environment a runtime `llama-server` child needs to find its libraries.
///
/// A managed runtime keeps `llama-server`, `libllama`, `libggml` and the
/// backend plugins side by side in one directory. The dynamic loader does not
/// look there by default, and `ggml` does not search it for plugins, so the
/// supervisor starts the child with that directory first on every loader path.
abstract final class RuntimeEnvironment {
  /// Loader variables that receive [directory] as their first entry.
  ///
  /// Windows resolves DLLs through `PATH`, macOS through `DYLD_LIBRARY_PATH`
  /// and Linux through `LD_LIBRARY_PATH`; every variable is set on every
  /// platform because an ignored variable is harmless and a missing one is not.
  static const List<String> loaderVariables = <String>[
    'LD_LIBRARY_PATH',
    'DYLD_LIBRARY_PATH',
    'PATH',
  ];

  /// The `ggml` backend plugin search path.
  static const String backendVariable = 'GGML_BACKEND_PATH';

  /// Overrides for a child started from [directory].
  ///
  /// [base] is the environment the prefix is built on; it defaults to the
  /// current process, which is what `Process.start` inherits anyway. Only the
  /// variables listed above are returned, so the caller can pass the map as a
  /// partial environment and keep every other inherited value.
  static Map<String, String> forDirectory(
    String directory, {
    Map<String, String>? base,
    String? operatingSystem,
  }) {
    final environment = base ?? Platform.environment;
    final separator = (operatingSystem ?? Platform.operatingSystem) == 'windows'
        ? ';'
        : ':';
    final overrides = <String, String>{backendVariable: directory};
    for (final name in loaderVariables) {
      final existing = environment[name]?.trim() ?? '';
      overrides[name] = existing.isEmpty
          ? directory
          : '$directory$separator$existing';
    }
    return overrides;
  }
}
