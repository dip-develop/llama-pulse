import 'dart:io';

import 'package:yaml/yaml.dart';

/// Locates the checked-in catalog inputs from a package-relative test.
final class CatalogFiles {
  CatalogFiles._(this.repoRoot);

  /// Repository root that contains `third_party/llama_cpp/v0.8.0`.
  final Directory repoRoot;

  static CatalogFiles? _cached;

  /// Resolves the paths, walking up from the current directory.
  static CatalogFiles get instance => _cached ??= CatalogFiles._(_findRoot());

  /// Vendored upstream `common/arg.cpp`.
  File get upstreamArgSource =>
      File('${repoRoot.path}/third_party/llama_cpp/v0.8.0/source/arg.cpp');

  /// Generated catalog document.
  File get catalog => File(
    '${repoRoot.path}/packages/llama_pulse_core/catalog/'
    'llama_args.v0.8.0.yaml',
  );

  /// Reviewed overrides consumed by the generator.
  File get overrides => File(
    '${repoRoot.path}/packages/llama_pulse_core/catalog/'
    'llama_args.v0.8.0.overrides.yaml',
  );

  /// Reads [file] as a YAML document converted to plain Dart collections.
  Map<String, Object?> readYaml(File file) {
    final decoded = loadYaml(file.readAsStringSync());
    final plain = toPlain(decoded);
    if (plain is! Map<String, Object?>) {
      throw StateError('${file.path} is not a YAML mapping');
    }
    return plain;
  }

  /// Converts YAML nodes to `Map<String, Object?>` / `List<Object?>`.
  static Object? toPlain(Object? value) {
    if (value is Map<Object?, Object?>) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): toPlain(entry.value),
      };
    }
    if (value is List<Object?>) {
      return <Object?>[for (final item in value) toPlain(item)];
    }
    return value;
  }

  static Directory _findRoot() {
    var directory = Directory.current.absolute;
    while (true) {
      if (File('${directory.path}/third_party/llama_cpp/v0.8.0/source/arg.cpp')
          .existsSync()) {
        return directory;
      }
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError(
          'could not find the repository root above ${Directory.current.path}',
        );
      }
      directory = parent;
    }
  }
}
