/// Stages a LlamaPulse desktop bundle and writes its archive.
///
/// This is the cross-platform replacement for `tool/package_linux.sh`.
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

import 'packaging/archive_writer.dart';
import 'packaging/package_plan.dart';
import 'packaging/package_target.dart';
import 'packaging/process_runner.dart';
import 'packaging/staging.dart';

/// Entry point used by `dart run`.
Future<void> main(List<String> arguments) async {
  final code = await runPackageApp(arguments, out: stdout, err: stderr);
  exitCode = code;
}

/// Runs the packager and returns the process exit code.
///
/// [out] and [err] are sinks so tests can capture the output without spawning a
/// process. [repoRoot], [hostArch] and [processRunner] are injectable for the
/// same reason; the command line does not expose them.
///
/// Exit codes:
///
/// * `0` success, including `--help`, `--check` and a written archive;
/// * `1` a missing bundle or runtime, a failed build, a filesystem error, or an
///   incomplete layout / archive;
/// * `2` a usage or validation error, including an unsupported ABI or target.
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

  final String arch;
  try {
    arch = hostArch ?? archFromAbi();
  } on UnsupportedError catch (error) {
    err.writeln('error: ${error.message}');
    return 2;
  }
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
    final platform = target.runtimePlatform(arch);
    if (platform == null) {
      err.writeln(
        '--runtime is not supported for ${target.artifactId(arch)}: '
        'LlamaPulse publishes runtime assets only for linux-x64, '
        'windows-x64 and macos-arm64.',
      );
      return 2;
    }
    // Reject an unknown or unpublished backend before looking for an
    // installed runtime, so a typo does not report "install it first".
    final selectionProblems = runtimeSelectionProblems(
      runtimeTag: runtimeTag,
      runtimeBackend: runtimeBackend,
      platform: platform,
    );
    if (selectionProblems.isNotEmpty) {
      for (final problem in selectionProblems) {
        err.writeln('error: $problem');
      }
      return 2;
    }
  }

  final outOption = result.option('out');
  final bundleOption = result.option('bundle');
  if (outOption != null && outOption.isEmpty) {
    _usageError(err, '--out must not be empty', parser);
    return 2;
  }
  if (bundleOption != null && bundleOption.isEmpty) {
    _usageError(err, '--bundle must not be empty', parser);
    return 2;
  }

  final outDir = p.normalize(p.absolute(outOption ?? p.join(root, 'dist')));
  var bundleDir = p.normalize(
    p.absolute(bundleOption ?? target.defaultBundleDir(root)),
  );
  final skipBuild = result.flag('skip-build');
  final check = result.flag('check');

  // A `--bundle` symlink to a directory must be resolved before copying;
  // otherwise the copy would try to recreate the root as a link.
  if (FileSystemEntity.typeSync(bundleDir, followLinks: false) ==
      FileSystemEntityType.link) {
    try {
      bundleDir = Directory(bundleDir).resolveSymbolicLinksSync();
    } on FileSystemException catch (error) {
      err.writeln(
        'error: cannot resolve --bundle $bundleDir: '
        '${error.message}',
      );
      return 1;
    }
  }

  if (skipBuild && !Directory(bundleDir).existsSync()) {
    err.writeln('no bundle at $bundleDir; build it or pass --bundle');
    return 1;
  }

  final configDir = _configDirectory(result.option('config-dir'));
  String? runtimeSource;
  if (runtimeTag != null && runtimeBackend != null) {
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

  final stagePath = p.join(outDir, stageName(version, target, arch: arch));
  if (p.equals(stagePath, bundleDir) || p.isWithin(bundleDir, stagePath)) {
    err.writeln(
      'error: --out resolves the stage to $stagePath, inside the bundle at '
      '$bundleDir; choose an --out outside the bundle',
    );
    return 2;
  }
  final archive = p.join(outDir, archiveName(version, target, arch: arch));
  final runtime = runtimeTag == null || runtimeBackend == null
      ? null
      : (tag: runtimeTag, backend: runtimeBackend);
  final entries = requiredEntries(target, stagePath, runtime: runtime);

  out.writeln(
    _plan(
      target: target,
      arch: arch,
      version: version,
      bundleDir: bundleDir,
      outDir: outDir,
      stage: stagePath,
      archive: archive,
      skipBuild: skipBuild,
      runtime: runtime,
      runtimeSource: runtimeSource,
      entryCount: entries.length,
      check: check,
      flutterExecutable: flutterExecutable(),
    ),
  );

  Directory? temporaryStage;
  try {
    final stageDir = check
        ? (temporaryStage = await Directory.systemTemp.createTemp(
            'llama-pulse-check-',
          )).path
        : stagePath;
    final staged = await stage(
      target: target,
      bundleDir: bundleDir,
      stageDir: stageDir,
      repoRoot: root,
      runtimeTag: runtimeTag,
      runtimeBackend: runtimeBackend,
      configDir: configDir,
      runner: processRunner,
      skipBuild: skipBuild,
      arch: arch,
    );
    if (!staged.isOk) {
      for (final problem in staged.problems) {
        err.writeln('layout problem: $problem');
      }
      return 1;
    }

    if (check) {
      out.writeln('checked ${staged.stageDir} (no archive written)');
      return 0;
    }

    await writeArchive(
      target: target,
      stageDir: staged.stageDir,
      archivePath: archive,
      runner: processRunner,
    );
    final problems = await verifyArchive(
      target: target,
      archivePath: archive,
      stageDir: staged.stageDir,
      runtime: runtime,
      runner: processRunner,
    );
    if (problems.isNotEmpty) {
      for (final problem in problems) {
        err.writeln('archive problem: $problem');
      }
      return 1;
    }

    final size = File(archive).lengthSync();
    final name = p.basename(stagePath);
    out
      ..writeln('created $archive (${_humanSize(size)}, verified)')
      ..writeln('run: ${_runHint(target, name, archive)}');
    return 0;
  } on UnsupportedError catch (error) {
    err.writeln('error: ${error.message}');
    return 2;
  } on FileSystemException catch (error) {
    err.writeln('error: ${_fileSystemMessage(error)}');
    return 1;
  } on StageException catch (error) {
    err.writeln(error.message);
    return 1;
  } on ArchiveException catch (error) {
    err.writeln(error.message);
    return 1;
  } on ProcessException catch (error) {
    err.writeln('cannot run ${error.executable}: ${error.message}');
    return 1;
  } finally {
    if (temporaryStage != null && temporaryStage.existsSync()) {
      temporaryStage.deleteSync(recursive: true);
    }
  }
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
    help: 'Use --bundle as-is; do not run a Flutter build.',
  )
  ..addFlag(
    'check',
    negatable: false,
    help: 'Stage into a temporary directory and verify; write no archive.',
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
      'Stage a relocatable LlamaPulse desktop bundle and write its archive '
      'for Linux, Windows or macOS.',
    )
    ..writeln(
      'Without --check the tool builds (unless --skip-build), copies, writes '
      'and verifies the archive. --check stages into a temporary directory '
      'and verifies it without writing an archive.',
    )
    ..writeln()
    ..writeln('Options:')
    ..write(parser.usage)
    ..writeln()
    ..writeln(
      'Exit codes: 0 success, 1 missing bundle/runtime, a filesystem error or '
      'a verification problem, 2 usage or validation error.',
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
}) {
  final build = skipBuild
      ? 'skipped (--skip-build)'
      : '$flutterExecutable build ${target.os} --release';
  final buffer = StringBuffer()
    ..writeln('LlamaPulse packaging plan')
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
      '  check:     stage and verify the layout, then discard the stage; '
      'no archive is written',
    );
  }
  return buffer.toString();
}

String _fileSystemMessage(FileSystemException error) {
  final path = error.path;
  if (path == null || path.isEmpty) {
    return error.message;
  }
  return '${error.message}: $path';
}

String _humanSize(int bytes) {
  const units = <String>['B', 'KiB', 'MiB', 'GiB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

String _runHint(PackageTarget target, String name, String archive) =>
    switch (target) {
      PackageTarget.linux => 'tar -xzf $archive && ./$name/llama_pulse',
      PackageTarget.windows => 'unzip $archive and run $name\\llama_pulse.exe',
      PackageTarget.macos => 'unzip $archive && open $name/llama_pulse.app',
    };

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
