import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/inference_failure.dart';
import '../../domain/entities/inference_failure_code.dart';
import '../../domain/entities/runtime_install_ref.dart';
import '../config/app_paths.dart';
import '../runtime/bundled_runtimes.dart';
import '../runtime/runtime_index_file.dart';
import '../serialization/serializers.dart' as core;

/// Resolves the llama.cpp shared library a worker should `dlopen`.
///
/// Every input is injectable so the resolution order can be tested without a
/// native library on disk. Nothing here opens the library; the worker does.
///
/// Tests may pass a [pathContext] for a foreign host to exercise Windows or
/// macOS path shapes on Linux. Production must leave it null so the host's
/// path context is used; the file existence checks in [resolveExisting] still
/// run against the real filesystem.
final class LlamaLibraryLocator {
  LlamaLibraryLocator({
    String? explicitPath,
    Map<String, String>? environment,
    String? operatingSystem,
    String? executablePath,
    String? configDirectory,
    p.Context? pathContext,
  }) : _explicitPath = explicitPath == null ? null : _requirePath(explicitPath),
       _environment = environment ?? Platform.environment,
       _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _executablePath = executablePath ?? Platform.resolvedExecutable,
       _configDirectory =
           configDirectory ??
           _defaultConfigDirectory(environment, operatingSystem),
       _path = pathContext ?? p.context;

  final String? _explicitPath;
  final Map<String, String> _environment;
  final String _operatingSystem;
  final String? _executablePath;
  final String? _configDirectory;
  final p.Context _path;

  /// The platform's shared-library file name.
  String get libraryFileName => switch (_operatingSystem) {
    'macos' => 'libllama.dylib',
    'windows' => 'llama.dll',
    _ => 'libllama.so',
  };

  /// Candidate library paths in resolution order, de-duplicated.
  ///
  /// Installed runtimes under `<config>/runtime/<tag>/<backend>` come before
  /// `<config>/lib`, with the selected runtime first and the others newest
  /// first. A runtime shipped beside the executable
  /// (`<exeDir>/runtime/<tag>/<backend>`) is the fallback after those and
  /// before `<config>/lib`; a macOS bundle also looks in
  /// `<exeDir>/../Resources/runtime/<tag>/<backend>`, which wins over
  /// `<exeDir>/runtime`. The last entry is the bare file name: it is never
  /// checked for existence here because `dlopen` may still resolve it through
  /// the loader.
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
        : _absolute(_path.dirname(_executablePath));
    if (executableDirectory != null) {
      add(_path.join(executableDirectory, 'lib', libraryFileName));
      add(_path.join(executableDirectory, libraryFileName));
      add(_path.join(executableDirectory, '..', 'Frameworks', libraryFileName));
    }

    final configDirectory = _configDirectory;
    if (configDirectory != null) {
      final absoluteConfig = _absolute(configDirectory);
      for (final install in _runtimeInstalls(absoluteConfig)) {
        add(
          _path.join(
            absoluteConfig,
            'runtime',
            install.tag,
            install.backend.id,
            libraryFileName,
          ),
        );
      }
    }

    if (executableDirectory != null) {
      for (final directory in BundledRuntimes.directories(
        executableDirectory,
        macOsBundle: _isMacOs,
      )) {
        add(_path.join(directory, libraryFileName));
      }
    }

    if (configDirectory != null) {
      add(_path.join(_absolute(configDirectory), 'lib', libraryFileName));
    }

    add(libraryFileName);

    return List.unmodifiable(found);
  }

  /// Installed runtimes in the order the loader must prefer them.
  ///
  /// The read is synchronous because [candidates] is a getter and the worker
  /// resolves once at startup; a corrupt index reads as "none installed".
  Iterable<RuntimeInstallRef> _runtimeInstalls(String absoluteConfig) {
    final indexFile = File(
      RuntimeIndexFile.pathFor(_path.join(absoluteConfig, 'runtime')),
    );
    return RuntimeIndexFile.readSync(
      indexFile,
      core.serializers,
    ).resolutionOrder;
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

  bool get _isMacOs => _operatingSystem == 'macos';

  static String _requirePath(String path) {
    if (path.trim().isEmpty) {
      throw ArgumentError.value(path, 'explicitPath', 'must not be empty');
    }
    return path;
  }

  bool _isBare(String path) =>
      !_path.isAbsolute(path) && !path.contains(_path.separator);

  String _absolute(String path) => _path.normalize(
    _path.isAbsolute(path) ? path : _path.join(Directory.current.path, path),
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
