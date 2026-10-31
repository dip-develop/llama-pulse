import 'dart:convert';

import '../../domain/entities/server_binary_info.dart';
import '../../domain/gateways/process_executor.dart';

/// Reads and classifies the version of a `llama-server` executable.
final class ServerVersionParser {
  /// Creates a parser that runs `<path> --version` through [_executor].
  ServerVersionParser(this._executor);

  /// Builds before this upstream build do not know every flag LlamaPulse sets.
  static const int minimumBuild = 4000;

  static const String _unsupportedWarning =
      'unsupported or unknown llama.cpp build; supported from b4000';
  static const String _unreadableWarning =
      'could not read llama-server --version';

  static final RegExp _fullVersion = RegExp(
    r'version:\s*([^\s(]+)\s*\(build\s+(\d+),\s*commit\s+([0-9a-fA-F]+)\)',
  );
  static final RegExp _bareBuild = RegExp(r'\bb(\d+)\b');

  final ProcessExecutor _executor;

  /// Runs `<path> --version` and parses its output.
  Future<ServerBinaryInfo> parse(String path) async {
    final output = await _executor.run(path, const ['--version']);
    if (!output.ok) {
      return ServerBinaryInfo(
        (b) => b
          ..path = path
          ..version = 'unknown'
          ..supported = true
          ..warning = _unreadableWarning
          ..rawOutput = output.stderr.trim(),
      );
    }
    final text = output.stdout.trim().isNotEmpty
        ? output.stdout
        : output.stderr;
    return parseOutput(path, text);
  }

  /// Parses captured version [output] for the executable at [path].
  ///
  /// Never throws: an unrecognised or empty output becomes an unsupported
  /// warning instead of a failure.
  static ServerBinaryInfo parseOutput(String path, String output) {
    final raw = output.trim();
    if (raw.isEmpty) {
      return _info(
        path: path,
        version: 'unknown',
        buildNumber: null,
        commit: null,
        rawOutput: raw,
        unknownVersion: true,
      );
    }

    final full = _fullVersion.firstMatch(raw);
    if (full != null) {
      final build = int.tryParse(full.group(2)!);
      if (build != null) {
        return _info(
          path: path,
          version: full.group(1)!,
          buildNumber: build,
          commit: full.group(3),
          rawOutput: raw,
        );
      }
    }

    final bare = _bareBuild.firstMatch(raw);
    if (bare != null) {
      final build = int.tryParse(bare.group(1)!);
      if (build != null) {
        return _info(
          path: path,
          version: 'b$build',
          buildNumber: build,
          commit: null,
          rawOutput: raw,
        );
      }
    }

    final firstLine = const LineSplitter()
        .convert(raw)
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
    return _info(
      path: path,
      version: firstLine.trim(),
      buildNumber: null,
      commit: null,
      rawOutput: raw,
      unknownVersion: true,
    );
  }

  static ServerBinaryInfo _info({
    required String path,
    required String version,
    required int? buildNumber,
    required String? commit,
    required String rawOutput,
    bool unknownVersion = false,
  }) {
    final supported = buildNumber == null || buildNumber >= minimumBuild;
    return ServerBinaryInfo(
      (b) => b
        ..path = path
        ..version = version
        ..buildNumber = buildNumber
        ..commit = commit
        ..supported = supported
        ..warning = supported && !unknownVersion ? null : _unsupportedWarning
        ..rawOutput = rawOutput,
    );
  }
}
