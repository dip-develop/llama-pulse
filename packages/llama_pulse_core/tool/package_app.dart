/// Prints the packaging plan for one LlamaPulse desktop target.
///
/// This is the cross-platform replacement for `tool/package_linux.sh`. Steps 5
/// and 6 add staging and archive creation; until then the tool validates its
/// inputs, prints what it would do, and never writes to disk.
///
/// Usage:
///
/// ```
/// dart run packages/llama_pulse_core/tool/package_app.dart --help
/// dart run packages/llama_pulse_core/tool/package_app.dart --os windows \
///   --skip-build --bundle apps/llama_pulse/build/windows/x64/runner/Release
/// ```
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;

import 'packaging/package_plan.dart';
import 'packaging/package_target.dart';
import 'packaging/process_runner.dart';

/// Entry point used by `dart run`.
Future<void> main(List<String> arguments) async {
  final code = await runPackageApp(arguments, out: stdout, err: stderr);
  exitCode = code;
}

/// Runs the planner and returns the process exit code.
///
/// [out] and [err] are sinks so tests can capture the plan without spawning a
/// process. [repoRoot], [hostArch] and [processRunner] are injectable for the
/// same reason; the command line does not expose them.
///
/// Exit codes:
///
/// * `0` success, including `--help`;
/// * `1` a missing bundle or runtime, or an unreadable app pubspec;
/// * `2` a usage or validation error.
Future<int> runPackageApp(
  List<String> arguments, {
  required StringSink out,
  required StringSink err,
  String? repoRoot,
  String? hostArch,
  ProcessRunner processRunner = const SystemProcessRunner(),
}) async {
  final parser = _buildParser();

  if (arguments.contains('--help') || arguments.contains('-h')) {
    out.write(_usage(parser));
    return 0;
  }

  final extracted = _extractRuntime(arguments);
  if (extracted.error != null) {
    _usageError(err, extracted.error!, parser);
    return 2;
  }

  final ArgResults result;
  try {
    result = parser.parse(extracted.remaining);
  } on FormatException catch (error) {
    _usageError(err, error.message, parser);
    return 2;
  }
  if (result.wasParsed('runtime')) {
    _usageError(err, '--runtime needs a tag and a backend', parser);
    return 2;
  }
  if (result.rest.isNotEmpty) {
    _usageError(err, 'unexpected argument: ${result.rest.first}', parser);
    return 2;
  }

  final hostOs = _hostOs();
  final osName = result.option('os') ?? hostOs;
  if (osName == null) {
    _usageError(
      err,
      'cannot detect the host OS; pass --os linux|windows|macos',
      parser,
    );
    return 2;
  }
  final target = switch (osName) {
    'linux' => PackageTarget.linux,
    'windows' => PackageTarget.windows,
    'macos' => PackageTarget.macos,
    _ => null,
  };
  if (target == null) {
    _usageError(err, 'unknown target OS: $osName', parser);
    return 2;
  }

  final arch = hostArch ?? archFromAbi();
  final root = repoRoot ?? repoRootFromScript(Platform.script);

  final String version;
  try {
    version = versionFromPubspecText(
      File(p.join(root, 'apps', 'llama_pulse', 'pubspec.yaml'))
          .readAsStringSync(),
    );
  } on FileSystemException catch (error) {
    err.writeln('cannot read apps/llama_pulse/pubspec.yaml: ${error.message}');
    return 1;
  } on FormatException catch (error) {
    err.writeln(
      'cannot read the app version from apps/llama_pulse/pubspec.yaml: '
      '${error.message}',
    );
    return 1;
  }

  final runtimeTag = extracted.tag;
  final runtimeBackend = extracted.backend;
  if (runtimeTag != null && runtimeBackend != null) {
    if (!_tagPattern.hasMatch(runtimeTag) ||
        runtimeTag == '.' ||
        runtimeTag == '..') {
      _usageError(err, 'invalid runtime tag: $runtimeTag', parser);
      return 2;
    }
    if (!_backendPattern.hasMatch(runtimeBackend)) {
      _usageError(err, 'invalid runtime backend: $runtimeBackend', parser);
      return 2;
    }
    if (target.runtimePlatform(arch) == null) {
      err.writeln(
        '--runtime is not supported for ${target.artifactId(arch)}: '
        'LlamaPulse publishes runtime assets only for linux-x64, '
        'windows-x64 and macos-arm64.',
      );
      return 2;
    }
  }

  final outDir = p.normalize(
    p.absolute(result.option('out') ?? p.join(root, 'dist')),
  );
  final bundleDir = p.normalize(
    p.absolute(result.option('bundle') ?? target.defaultBundleDir(root)),
  );
  final skipBuild = result.flag('skip-build');
  final check = result.flag('check');

  if (skipBuild && !Directory(bundleDir).existsSync()) {
    err.writeln('no bundle at $bundleDir; build it or pass --bundle');
    return 1;
  }

  String? runtimeSource;
  if (runtimeTag != null && runtimeBackend != null) {
    final configDir = _configDirectory(result.option('config-dir'));
    if (configDir == null) {
      err.writeln(
        'cannot resolve the config directory; pass --config-dir or set '
        'LLAMA_PULSE_CONFIG_DIR',
      );
      return 1;
    }
    runtimeSource = p.join(configDir, 'runtime', runtimeTag, runtimeBackend);
    final server = File(p.join(runtimeSource, target.runtimeExecutableName));
    if (!server.existsSync()) {
      err.writeln(
        'no ${target.runtimeExecutableName} in $runtimeSource; '
        'install the runtime first:',
      );
      err.writeln('  llamapulse runtime install --backend $runtimeBackend');
      return 1;
    }
  }

  final stage = p.join(outDir, stageName(version, target, arch: arch));
  final archive = p.join(outDir, archiveName(version, target, arch: arch));
  final runtime = runtimeTag == null || runtimeBackend == null
      ? null
      : (tag: runtimeTag, backend: runtimeBackend);
  final entries = requiredEntries(target, stage, runtime: runtime);

  out.writeln(
    _plan(
      target: target,
      arch: arch,
      version: version,
      bundleDir: bundleDir,
      outDir: outDir,
      stage: stage,
      archive: archive,
      skipBuild: skipBuild,
      runtime: runtime,
      runtimeSource: runtimeSource,
      entryCount: entries.length,
      check: check,
      flutterExecutable: flutterExecutable(),
      processRunner: processRunner,
    ),
  );
  return 0;
}

ArgParser _buildParser() => ArgParser()
  ..addOption(
    'os',
    allowed: <String>['linux', 'windows', 'macos'],
    valueHelp: 'linux|windows|macos',
    help: 'Target operating system; defaults to the host.',
  )
  ..addOption(
    'runtime',
    valueHelp: 'tag backend',
    help:
        'Bundle an installed managed runtime, for example '
        '`--runtime v0.8.0 cuda13`.',
  )
  ..addOption(
    'config-dir',
    valueHelp: 'dir',
    help:
        'Config directory holding runtime/ (default: '
        'LLAMA_PULSE_CONFIG_DIR, then the platform config directory).',
  )
  ..addOption(
    'out',
    valueHelp: 'dir',
    help: 'Output directory (default: <repo>/dist).',
  )
  ..addOption(
    'bundle',
    valueHelp: 'dir',
    help: 'App bundle to package (default: the target Flutter release output).',
  )
  ..addFlag(
    'skip-build',
    negatable: false,
    help: 'Use --bundle as-is; do not plan a Flutter build.',
  )
  ..addFlag(
    'check',
    negatable: false,
    help: 'Validate inputs and print the plan without writing anything.',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

String _usage(ArgParser parser) {
  final buffer = StringBuffer()
    ..writeln(
      'usage: dart run packages/llama_pulse_core/tool/package_app.dart '
      '[options]',
    )
    ..writeln()
    ..writeln(
      'Plan a relocatable LlamaPulse desktop bundle for Linux, Windows or '
      'macOS.',
    )
    ..writeln(
      'This preview prints the plan only; it does not build, copy or write '
      'anything yet.',
    )
    ..writeln()
    ..writeln('Options:')
    ..write(parser.usage)
    ..writeln()
    ..writeln(
      'Exit codes: 0 success, 1 missing bundle/runtime, 2 usage error.',
    );
  return buffer.toString();
}

void _usageError(StringSink err, String message, ArgParser parser) {
  err
    ..writeln('error: $message')
    ..writeln()
    ..write(_usage(parser));
}

String _plan({
  required PackageTarget target,
  required String arch,
  required String version,
  required String bundleDir,
  required String outDir,
  required String stage,
  required String archive,
  required bool skipBuild,
  required RuntimeSelection? runtime,
  required String? runtimeSource,
  required int entryCount,
  required bool check,
  required String flutterExecutable,
  required ProcessRunner processRunner,
}) {
  final build = skipBuild
      ? 'skipped (--skip-build)'
      : '$flutterExecutable build ${target.os} --release';
  final buffer = StringBuffer()
    ..writeln('LlamaPulse packaging plan (no files are written yet)')
    ..writeln()
    ..writeln('  target:    ${target.artifactId(arch)}')
    ..writeln('  version:   $version')
    ..writeln('  bundle:    $bundleDir')
    ..writeln('  build:     $build')
    ..writeln('  output:    $outDir')
    ..writeln('  stage:     $stage')
    ..writeln('  archive:   $archive')
    ..writeln('  format:    ${target.archiveKind.name}')
    ..writeln(
      '  runtime:   ${runtime == null ? 'none' : '${runtime.tag}/${runtime.backend}'}'
      '${runtimeSource == null ? '' : ' from $runtimeSource'}',
    )
    ..writeln('  entries:   $entryCount required');
  if (check) {
    buffer.writeln(
      '  check:     inputs valid; staging layout is verified once steps 5-6 '
      'land',
    );
  }
  return buffer.toString();
}

String? _hostOs() {
  if (Platform.isLinux) {
    return 'linux';
  }
  if (Platform.isWindows) {
    return 'windows';
  }
  if (Platform.isMacOS) {
    return 'macos';
  }
  return null;
}

String? _configDirectory(String? explicit) {
  if (explicit != null && explicit.isNotEmpty) {
    return p.normalize(p.absolute(explicit));
  }
  try {
    return AppPaths.resolve().configDirectory;
  } on StateError {
    return null;
  }
}

final RegExp _tagPattern = RegExp(r'^[A-Za-z0-9._-]+$');
final RegExp _backendPattern = RegExp(r'^[a-z0-9]+$');

final class _ExtractedRuntime {
  const _ExtractedRuntime({
    required this.remaining,
    this.tag,
    this.backend,
    this.error,
  });

  final List<String> remaining;
  final String? tag;
  final String? backend;
  final String? error;
}

/// Pulls `--runtime <tag> <backend>` out of [arguments].
///
/// [ArgParser] options take one value, so the pair is consumed here and the
/// rest is parsed normally. Keeping the option declared on the parser lets
/// `--help` list it.
_ExtractedRuntime _extractRuntime(List<String> arguments) {
  final remaining = <String>[];
  String? tag;
  String? backend;
  for (var index = 0; index < arguments.length; index++) {
    if (arguments[index] != '--runtime') {
      remaining.add(arguments[index]);
      continue;
    }
    if (index + 2 >= arguments.length) {
      return const _ExtractedRuntime(
        remaining: <String>[],
        error: '--runtime needs a tag and a backend',
      );
    }
    tag = arguments[index + 1];
    backend = arguments[index + 2];
    index += 2;
  }
  return _ExtractedRuntime(remaining: remaining, tag: tag, backend: backend);
}
