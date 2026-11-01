import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/inference_failure.dart';
import '../../domain/entities/inference_failure_code.dart';
import '../config/app_paths.dart';

/// Resolves the llama.cpp shared library a worker should `dlopen`.
///
/// Every input is injectable so the resolution order can be tested without a
/// native library on disk. Nothing here opens the library; the worker does.
final class LlamaLibraryLocator {
  LlamaLibraryLocator({
    String? explicitPath,
    Map<String, String>? environment,
    String? operatingSystem,
    String? executablePath,
    String? configDirectory,
  }) : _explicitPath = explicitPath == null ? null : _requirePath(explicitPath),
       _environment = environment ?? Platform.environment,
       _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _executablePath = executablePath ?? Platform.resolvedExecutable,
       _configDirectory =
           configDirectory ??
           _defaultConfigDirectory(environment, operatingSystem);

  final String? _explicitPath;
  final Map<String, String> _environment;
  final String _operatingSystem;
  final String? _executablePath;
  final String? _configDirectory;

  /// The platform's shared-library file name.
  String get libraryFileName => switch (_operatingSystem) {
    'macos' => 'libllama.dylib',
    'windows' => 'llama.dll',
    _ => 'libllama.so',
  };

  /// Candidate library paths in resolution order, de-duplicated.
  ///
  /// The last entry is the bare file name: it is never checked for existence
  /// here because `dlopen` may still resolve it through the loader.
  List<String> get candidates {
    final seen = <String>{};
    final found = <String>[];

    void add(String? path) {
      if (path == null || path.isEmpty) {
        return;
      }
      final candidate = _isBare(path) ? path : _absolute(path);
      if (seen.add(candidate)) {
        found.add(candidate);
      }
    }

    add(_explicitPath);

    final fromEnvironment = _environment['LLAMA_PULSE_LIB'];
    if (fromEnvironment != null && fromEnvironment.trim().isNotEmpty) {
      add(fromEnvironment);
    }

    final executableDirectory = _executablePath == null
        ? null
        : _absolute(p.dirname(_executablePath));
    if (executableDirectory != null) {
      add(p.join(executableDirectory, 'lib', libraryFileName));
      add(p.join(executableDirectory, libraryFileName));
      add(p.join(executableDirectory, '..', 'Frameworks', libraryFileName));
    }

    final configDirectory = _configDirectory;
    if (configDirectory != null) {
      add(p.join(_absolute(configDirectory), 'lib', libraryFileName));
    }

    add(libraryFileName);

    return List.unmodifiable(found);
  }

  /// The first candidate that exists on disk, or null when none does.
  ///
  /// The bare file name is skipped: its existence is left to the loader.
  String? resolveExisting() {
    for (final candidate in candidates) {
      if (_isBare(candidate)) {
        continue;
      }
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  /// A `libraryNotFound` failure listing every path that was tried.
  InferenceFailure notFoundFailure() => InferenceFailure(
    (b) => b
      ..code = InferenceFailureCode.libraryNotFound
      ..message =
          'could not locate $libraryFileName; set LLAMA_PULSE_LIB '
          'or place it next to the executable'
      ..details = candidates.join('\n'),
  );

  static String _requirePath(String path) {
    if (path.trim().isEmpty) {
      throw ArgumentError.value(path, 'explicitPath', 'must not be empty');
    }
    return path;
  }

  static bool _isBare(String path) =>
      !p.isAbsolute(path) && !path.contains(p.separator);

  static String _absolute(String path) => p.normalize(
    p.isAbsolute(path) ? path : p.join(Directory.current.path, path),
  );

  static String? _defaultConfigDirectory(
    Map<String, String>? environment,
    String? operatingSystem,
  ) {
    try {
      return AppPaths.resolve(
        environment: environment,
        operatingSystem: operatingSystem,
      ).configDirectory;
    } on StateError {
      return null;
    }
  }
}
