import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/server_binary_info.dart';
import '../../domain/entities/server_config.dart';
import '../../domain/entities/server_failure.dart';
import '../../domain/entities/server_failure_code.dart';
import '../../domain/exceptions/server_exception.dart';
import '../../domain/gateways/runtime_store.dart';
import '../../domain/gateways/server_binary_locator.dart';
import '../config/app_paths.dart';
import '../runtime/bundled_runtimes.dart';
import '../runtime/yaml_runtime_store.dart';
import 'dart_process_executor.dart';
import 'server_version_parser.dart';

/// Resolves `llama-server` from configuration, the environment, the app
/// bundle, installed runtimes, the user data directory and `PATH`, in that
/// order.
///
/// Installed runtimes under `<config>/runtime/` (selected first, then newest)
/// win over a runtime shipped in the bundle; the bundled one keeps a fresh
/// installation working before anything has been downloaded.
final class ServerBinaryLocatorImpl implements ServerBinaryLocator {
  /// Creates a locator.
  ///
  /// [executablePath] is the running executable; its directory anchors the
  /// bundled candidates. [environment] and [operatingSystem] default to the
  /// current process. [versionReader] replaces version probing in tests.
  ///
  /// Tests may pass a [pathContext] for a foreign host to exercise Windows or
  /// macOS candidate shapes on Linux; every path is rendered with it. Production
  /// must leave it null so the host's path context is used; the file existence
  /// and executability checks still run against the real filesystem and the
  /// injected [operatingSystem].
  factory ServerBinaryLocatorImpl({
    required AppPaths paths,
    required String executablePath,
    Map<String, String>? environment,
    String? operatingSystem,
    Future<ServerBinaryInfo> Function(String path)? versionReader,
    RuntimeStore? runtimeStore,
    p.Context? pathContext,
  }) {
    final reader =
        versionReader ?? ServerVersionParser(const DartProcessExecutor()).parse;
    return ServerBinaryLocatorImpl._(
      paths,
      executablePath,
      environment ?? Platform.environment,
      operatingSystem ?? Platform.operatingSystem,
      reader,
      runtimeStore ?? YamlRuntimeStore(paths: paths),
      pathContext ?? p.context,
    );
  }

  ServerBinaryLocatorImpl._(
    this._paths,
    this._executablePath,
    this._environment,
    this._operatingSystem,
    this._versionReader,
    this._runtimeStore,
    this._path,
  );

  static const String _environmentVariable = 'LLAMA_PULSE_SERVER';

  final AppPaths _paths;
  final String _executablePath;
  final Map<String, String> _environment;
  final String _operatingSystem;
  final Future<ServerBinaryInfo> Function(String path) _versionReader;
  final RuntimeStore _runtimeStore;
  final p.Context _path;

  bool get _isWindows => _operatingSystem == 'windows';

  bool get _isMacOs => _operatingSystem == 'macos';

  String get _binaryName => _isWindows ? 'llama-server.exe' : 'llama-server';

  @override
  Future<ServerBinaryInfo> locate(ServerConfig config) async {
    final searched = <String>[];
    final notExecutable = <String>[];

    final explicit = config.binaryPath.trim();
    if (explicit.isNotEmpty) {
      final path = _path.normalize(_path.absolute(explicit));
      searched.add(path);
      if (!await _exists(path)) {
        throw _error(
          ServerFailureCode.binaryNotFound,
          'llama-server not found',
          searched,
        );
      }
      if (!_isExecutable(path)) {
        throw _error(
          ServerFailureCode.binaryNotExecutable,
          'llama-server is not executable',
          [path],
        );
      }
      return _describe(path);
    }

    final fromEnvironment = _environment[_environmentVariable]?.trim() ?? '';
    if (fromEnvironment.isNotEmpty) {
      final List<String> candidates;
      if (_path.isAbsolute(fromEnvironment)) {
        candidates = [fromEnvironment];
      } else if (fromEnvironment.contains('/') ||
          fromEnvironment.contains(r'\')) {
        candidates = [_path.absolute(fromEnvironment)];
      } else {
        candidates = _pathCandidates(fromEnvironment);
      }
      final found = await _firstRunnable(candidates, searched, notExecutable);
      if (found != null) {
        return _describe(found);
      }
    }

    final executableDirectory = _path.dirname(_path.absolute(_executablePath));
    final bundled = await _firstRunnable(
      [
        _path.join(executableDirectory, 'data', _binaryName),
        _path.join(executableDirectory, _binaryName),
      ],
      searched,
      notExecutable,
    );
    if (bundled != null) {
      return _describe(bundled);
    }

    final fromRuntime = await _firstRuntime(searched, notExecutable);
    if (fromRuntime != null) {
      return fromRuntime;
    }

    final fromBundle = await _firstBundledRuntime(
      executableDirectory,
      searched,
      notExecutable,
    );
    if (fromBundle != null) {
      return fromBundle;
    }

    final configured = await _firstRunnable(
      [_path.join(_paths.binDirectory, _binaryName)],
      searched,
      notExecutable,
    );
    if (configured != null) {
      return _describe(configured);
    }

    final onPath = await _firstRunnable(
      _pathCandidates(_binaryName),
      searched,
      notExecutable,
    );
    if (onPath != null) {
      return _describe(onPath);
    }

    if (notExecutable.isNotEmpty) {
      throw _error(
        ServerFailureCode.binaryNotExecutable,
        'llama-server is not executable',
        notExecutable,
      );
    }
    throw _error(
      ServerFailureCode.binaryNotFound,
      'llama-server not found',
      searched,
    );
  }

  Future<String?> _firstRunnable(
    Iterable<String> candidates,
    List<String> searched,
    List<String> notExecutable,
  ) async {
    for (final candidate in candidates) {
      final path = _path.normalize(_path.absolute(candidate));
      searched.add(path);
      if (!await _exists(path)) {
        continue;
      }
      if (!_isExecutable(path)) {
        notExecutable.add(path);
        continue;
      }
      return path;
    }
    return null;
  }

  /// The first installed runtime whose `llama-server` is runnable.
  ///
  /// Runtime installs are tried in [RuntimeIndex.resolutionOrder]: the selected
  /// one first, then the rest newest first.
  /// The first runtime shipped under `<exeDir>/runtime/<tag>/<backend>/` or,
  /// for a macOS bundle, `<exeDir>/../Resources/runtime/<tag>/<backend>/`.
  ///
  /// The directories are tried in the order [BundledRuntimes.directories]
  /// returns; the binary is described with its directory so the supervisor
  /// sets the loader environment for it.
  Future<ServerBinaryInfo?> _firstBundledRuntime(
    String executableDirectory,
    List<String> searched,
    List<String> notExecutable,
  ) async {
    for (final directory in BundledRuntimes.directories(
      executableDirectory,
      macOsBundle: _isMacOs,
      pathContext: _path,
    )) {
      final path = await _firstRunnable(
        [_path.join(directory, _binaryName)],
        searched,
        notExecutable,
      );
      if (path != null) {
        return _describe(path, runtimeDirectory: directory);
      }
    }
    return null;
  }

  Future<ServerBinaryInfo?> _firstRuntime(
    List<String> searched,
    List<String> notExecutable,
  ) async {
    final index = await _runtimeStore.index();
    for (final install in index.resolutionOrder) {
      final directory = _path.join(
        _paths.runtimeDirectory,
        install.tag,
        install.backend.id,
      );
      final path = await _firstRunnable(
        [_path.join(directory, _binaryName)],
        searched,
        notExecutable,
      );
      if (path != null) {
        return _describe(path, runtimeDirectory: directory);
      }
    }
    return null;
  }

  List<String> _pathCandidates(String name) {
    final raw = _environment['PATH'] ?? '';
    // The PATH list separator follows the path context, not the injected OS:
    // tests exercise a Windows-shaped list on a POSIX host.
    final separator = _path.style == p.Style.windows ? ';' : ':';
    return [
      for (final entry in raw.split(separator))
        if (entry.trim().isNotEmpty) _path.join(_unquote(entry.trim()), name),
    ];
  }

  static String _unquote(String value) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  static Future<bool> _exists(String path) => File(path).exists();

  bool _isExecutable(String path) {
    if (_isWindows) {
      return true;
    }
    try {
      return File(path).statSync().mode & 0x49 != 0;
    } on FileSystemException {
      return false;
    }
  }

  Future<ServerBinaryInfo> _describe(
    String path, {
    String? runtimeDirectory,
  }) async {
    final info = await _versionReader(path);
    final described =
        info.path == path && info.runtimeDirectory == runtimeDirectory
        ? info
        : info.rebuild(
            (b) => b
              ..path = path
              ..runtimeDirectory = runtimeDirectory,
          );
    return described;
  }

  static ServerException _error(
    ServerFailureCode code,
    String message,
    List<String> details,
  ) => ServerException(
    ServerFailure(
      (b) => b
        ..code = code
        ..message = message
        ..details = details.join('\n'),
    ),
  );
}
