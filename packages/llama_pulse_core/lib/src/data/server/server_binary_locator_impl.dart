import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/server_binary_info.dart';
import '../../domain/entities/server_config.dart';
import '../../domain/entities/server_failure.dart';
import '../../domain/entities/server_failure_code.dart';
import '../../domain/exceptions/server_exception.dart';
import '../../domain/gateways/server_binary_locator.dart';
import '../config/app_paths.dart';
import 'dart_process_executor.dart';
import 'server_version_parser.dart';

/// Resolves `llama-server` from configuration, the environment, the app
/// bundle, the user data directory and `PATH`, in that order.
final class ServerBinaryLocatorImpl implements ServerBinaryLocator {
  /// Creates a locator.
  ///
  /// [executablePath] is the running executable; its directory anchors the
  /// bundled candidates. [environment] and [operatingSystem] default to the
  /// current process. [versionReader] replaces version probing in tests.
  factory ServerBinaryLocatorImpl({
    required AppPaths paths,
    required String executablePath,
    Map<String, String>? environment,
    String? operatingSystem,
    Future<ServerBinaryInfo> Function(String path)? versionReader,
  }) {
    final reader =
        versionReader ?? ServerVersionParser(const DartProcessExecutor()).parse;
    return ServerBinaryLocatorImpl._(
      paths,
      executablePath,
      environment ?? Platform.environment,
      operatingSystem ?? Platform.operatingSystem,
      reader,
    );
  }

  ServerBinaryLocatorImpl._(
    this._paths,
    this._executablePath,
    this._environment,
    this._operatingSystem,
    this._versionReader,
  );

  static const String _environmentVariable = 'LLAMA_PULSE_SERVER';

  final AppPaths _paths;
  final String _executablePath;
  final Map<String, String> _environment;
  final String _operatingSystem;
  final Future<ServerBinaryInfo> Function(String path) _versionReader;

  bool get _isWindows => _operatingSystem == 'windows';

  String get _binaryName => _isWindows ? 'llama-server.exe' : 'llama-server';

  @override
  Future<ServerBinaryInfo> locate(ServerConfig config) async {
    final searched = <String>[];
    final notExecutable = <String>[];

    final explicit = config.binaryPath.trim();
    if (explicit.isNotEmpty) {
      final path = p.normalize(p.absolute(explicit));
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
      if (p.isAbsolute(fromEnvironment)) {
        candidates = [fromEnvironment];
      } else if (fromEnvironment.contains('/') ||
          fromEnvironment.contains(r'\')) {
        candidates = [p.absolute(fromEnvironment)];
      } else {
        candidates = _pathCandidates(fromEnvironment);
      }
      final found = await _firstRunnable(candidates, searched, notExecutable);
      if (found != null) {
        return _describe(found);
      }
    }

    final executableDirectory = p.dirname(p.absolute(_executablePath));
    final bundled = await _firstRunnable(
      [
        p.join(executableDirectory, 'data', _binaryName),
        p.join(executableDirectory, _binaryName),
        p.join(_paths.binDirectory, _binaryName),
      ],
      searched,
      notExecutable,
    );
    if (bundled != null) {
      return _describe(bundled);
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
      final path = p.normalize(p.absolute(candidate));
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

  List<String> _pathCandidates(String name) {
    final raw = _environment['PATH'] ?? '';
    final separator = _isWindows ? ';' : ':';
    return [
      for (final entry in raw.split(separator))
        if (entry.trim().isNotEmpty) p.join(_unquote(entry.trim()), name),
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

  Future<ServerBinaryInfo> _describe(String path) async {
    final info = await _versionReader(path);
    if (info.path == path) {
      return info;
    }
    return info.rebuild((b) => b..path = path);
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
