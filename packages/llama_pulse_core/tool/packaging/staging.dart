import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;

import 'package_plan.dart';
import 'package_target.dart';
import 'process_runner.dart';

/// Outcome of staging one bundle.
///
/// [problems] is empty when the layout matches [requiredEntries]. A non-empty
/// list means the caller must not archive the tree.
final class StageResult {
  /// Creates a result for the tree at [stageDir].
  const StageResult({required this.stageDir, required this.problems});

  /// Directory the bundle was copied into.
  final String stageDir;

  /// Missing or invalid entries, one string per problem.
  final List<String> problems;

  /// Whether the staged tree is complete.
  bool get isOk => problems.isEmpty;
}

/// Thrown when a build, a copy or an ad-hoc signature fails.
final class StageException implements Exception {
  /// Creates an exception with a human-readable [message].
  const StageException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// Copies the Flutter bundle into [stageDir] and verifies the layout.
///
/// Runs `flutter build <os> --release` in `apps/llama_pulse` unless
/// [skipBuild] is set. On macOS the whole `llama_pulse.app` is copied as one
/// unit, symlinks included, and the ad-hoc signature is refreshed afterwards.
///
/// When [runtimeTag] and [runtimeBackend] are set, the installed runtime at
/// `<configDir>/runtime/<tag>/<backend>` is copied verbatim into the location
/// the app resolves at launch. Invalid selections are returned in
/// [StageResult.problems] instead of throwing.
///
/// The caller passes [arch] when packaging for a target other than the host;
/// it defaults to the running ABI and selects the runtime platform.
Future<StageResult> stage({
  required PackageTarget target,
  required String bundleDir,
  required String stageDir,
  required String repoRoot,
  String? runtimeTag,
  String? runtimeBackend,
  String? configDir,
  ProcessRunner? runner,
  bool skipBuild = false,
  String? arch,
}) async {
  final process = runner ?? const SystemProcessRunner();
  final architecture = arch ?? archFromAbi();
  final problems = <String>[];

  final runtime = _validateRuntime(
    target: target,
    arch: architecture,
    runtimeTag: runtimeTag,
    runtimeBackend: runtimeBackend,
    configDir: configDir,
    problems: problems,
  );
  if (problems.isNotEmpty) {
    return StageResult(stageDir: stageDir, problems: problems);
  }

  if (!skipBuild) {
    await _build(target: target, repoRoot: repoRoot, runner: process);
  }

  if (!Directory(bundleDir).existsSync()) {
    return StageResult(
      stageDir: stageDir,
      problems: <String>['no bundle at $bundleDir; build it or pass --bundle'],
    );
  }

  if (Directory(stageDir).existsSync()) {
    Directory(stageDir).deleteSync(recursive: true);
  }
  Directory(stageDir).createSync(recursive: true);

  final isWindowsTarget = target == PackageTarget.windows;
  if (target == PackageTarget.macos) {
    _copyTree(
      bundleDir,
      p.join(stageDir, 'llama_pulse.app'),
      isWindowsTarget: false,
    );
  } else {
    _copyTree(bundleDir, stageDir, isWindowsTarget: isWindowsTarget);
  }

  for (final name in <String>['README.md', 'LICENSE']) {
    final source = p.join(repoRoot, name);
    if (File(source).existsSync()) {
      _copyFile(source, p.join(stageDir, name));
    }
  }

  if (runtime != null) {
    final destination = target.runtimeDirectoryInStage(
      stageDir,
      tag: runtime.selection.tag,
      backend: runtime.selection.backend,
    );
    _copyTree(runtime.sourceDir, destination, isWindowsTarget: isWindowsTarget);
  }

  if (target == PackageTarget.macos) {
    await _signAdHoc(p.join(stageDir, 'llama_pulse.app'), process, problems);
  }

  problems.addAll(verifyLayout(stageDir, target, runtime: runtime?.selection));
  return StageResult(stageDir: stageDir, problems: problems);
}

/// Validates a runtime tag and backend against the pinned release for
/// [platform].
///
/// Returns one message per invalid or unpublished input; an empty list means
/// the selection is one the pinned release ships for [platform]. No filesystem
/// access happens here, so callers can reject a bad selection before checking
/// whether the runtime is installed.
List<String> runtimeSelectionProblems({
  required String runtimeTag,
  required String runtimeBackend,
  required RuntimePlatform platform,
}) {
  final problems = <String>[];
  if (!_tagPattern.hasMatch(runtimeTag) ||
      runtimeTag == '.' ||
      runtimeTag.contains('..')) {
    problems.add('invalid runtime tag: $runtimeTag');
  }
  if (!_backendPattern.hasMatch(runtimeBackend) ||
      runtimeBackend.contains('..')) {
    problems.add('invalid runtime backend: $runtimeBackend');
  }
  if (problems.isNotEmpty) {
    return problems;
  }

  if (runtimeTag != RuntimeRelease.v080.tag) {
    return problems;
  }
  final backend = RuntimeBackend.fromId(runtimeBackend);
  if (backend == null) {
    problems
      ..add('unknown runtime backend: $runtimeBackend')
      ..add('use one of: ${_publishedBackends(platform)}');
    return problems;
  }
  if (RuntimeRelease.v080.forBackend(backend, platform) == null) {
    problems.add(
      'runtime backend $runtimeBackend is not published for '
      '${platform.id}; use one of: ${_publishedBackends(platform)}',
    );
  }
  return problems;
}

String _publishedBackends(RuntimePlatform platform) => RuntimeRelease.v080
    .backendsFor(platform)
    .map((candidate) => candidate.id)
    .join(', ');

/// Resolves and validates the runtime selected for [target].
///
/// Adds one problem per invalid input or missing required file and returns
/// `null` when anything is wrong, so [stage] can stop before touching disk.
_ResolvedRuntime? _validateRuntime({
  required PackageTarget target,
  required String arch,
  required String? runtimeTag,
  required String? runtimeBackend,
  required String? configDir,
  required List<String> problems,
}) {
  if (runtimeTag == null && runtimeBackend == null) {
    return null;
  }
  if (runtimeTag == null || runtimeBackend == null) {
    problems.add('--runtime needs a tag and a backend');
    return null;
  }

  final platform = target.runtimePlatform(arch);
  if (platform == null) {
    problems.add(
      '--runtime is not supported for ${target.artifactId(arch)}: '
      'LlamaPulse publishes runtime assets only for linux-x64, '
      'windows-x64 and macos-arm64.',
    );
    return null;
  }

  problems.addAll(
    runtimeSelectionProblems(
      runtimeTag: runtimeTag,
      runtimeBackend: runtimeBackend,
      platform: platform,
    ),
  );
  if (problems.isNotEmpty) {
    return null;
  }

  if (configDir == null) {
    problems.add(
      'cannot resolve the config directory; pass --config-dir or set '
      'LLAMA_PULSE_CONFIG_DIR',
    );
    return null;
  }

  final sourceDir = p.join(configDir, 'runtime', runtimeTag, runtimeBackend);
  if (!Directory(sourceDir).existsSync()) {
    problems.add('no runtime at $sourceDir; install it first');
    return null;
  }
  final server = File(p.join(sourceDir, target.runtimeExecutableName));
  if (!server.existsSync()) {
    problems.add('no ${target.runtimeExecutableName} in $sourceDir');
  }
  final manifest = File(p.join(sourceDir, 'runtime.yaml'));
  if (!manifest.existsSync()) {
    problems.add('no runtime.yaml in $sourceDir');
  }
  if (problems.isNotEmpty) {
    return null;
  }
  return _ResolvedRuntime(
    selection: (tag: runtimeTag, backend: runtimeBackend),
    sourceDir: sourceDir,
  );
}

/// Runs the Flutter release build for [target] in `apps/llama_pulse`.
Future<void> _build({
  required PackageTarget target,
  required String repoRoot,
  required ProcessRunner runner,
}) async {
  final result = await runner.run(
    // The launcher name follows the host, not the target: `flutter` has no
    // executable on Windows, whatever platform the bundle is for.
    flutterExecutable(),
    <String>['build', target.os, '--release'],
    workingDirectory: p.join(repoRoot, 'apps', 'llama_pulse'),
  );
  if (result.exitCode != 0) {
    throw StageException(
      'flutter build ${target.os} --release failed with exit '
      '${result.exitCode}: ${result.stderr}',
    );
  }
}

/// Refreshes the ad-hoc signature after resources were added to the app.
Future<void> _signAdHoc(
  String appPath,
  ProcessRunner runner,
  List<String> problems,
) async {
  final result = await runner.run('codesign', <String>[
    '--force',
    '--deep',
    '--sign',
    '-',
    appPath,
  ]);
  if (result.exitCode != 0) {
    problems.add('codesign failed for $appPath: ${result.stderr}');
  }
}

/// Recursively copies [source] to [destination], preserving modes and symlinks.
///
/// [isWindowsTarget] drops `*.pdb`, `*.exp` and `*.lib`, which are build
/// artefacts and never part of the shipped Windows bundle.
void _copyTree(
  String source,
  String destination, {
  required bool isWindowsTarget,
}) {
  final type = FileSystemEntity.typeSync(source, followLinks: false);
  if (type == FileSystemEntityType.directory) {
    Directory(destination).createSync(recursive: true);
    _copyMode(source, destination);
    for (final entity in Directory(source).listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (isWindowsTarget && _excludedWindowsArtifact(name)) {
        continue;
      }
      _copyTree(
        entity.path,
        p.join(destination, name),
        isWindowsTarget: isWindowsTarget,
      );
    }
    return;
  }
  if (type == FileSystemEntityType.link) {
    Link(destination).createSync(Link(source).targetSync());
    return;
  }
  if (type == FileSystemEntityType.file) {
    File(source).copySync(destination);
    _copyMode(source, destination);
    return;
  }
  throw StageException('cannot copy $source: unsupported file type');
}

void _copyFile(String source, String destination) {
  File(source).copySync(destination);
  _copyMode(source, destination);
}

bool _excludedWindowsArtifact(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.pdb') ||
      lower.endsWith('.exp') ||
      lower.endsWith('.lib');
}

/// Applies the source's permission bits to [destination].
///
/// Dart has no chmod API; `chmod` is used on POSIX hosts so the executable bit
/// of the Flutter bundle and the runtime survives the copy. Windows has no
/// comparable bit, so this is a no-op there.
void _copyMode(String source, String destination) {
  if (Platform.isWindows) {
    return;
  }
  final mode = FileStat.statSync(source).mode & 0xFFF;
  final result = Process.runSync('chmod', <String>[
    mode.toRadixString(8),
    destination,
  ]);
  if (result.exitCode != 0) {
    throw StageException('chmod failed for $destination: ${result.stderr}');
  }
}

final RegExp _tagPattern = RegExp(r'^[A-Za-z0-9._-]+$');
final RegExp _backendPattern = RegExp(r'^[a-z0-9]+$');

final class _ResolvedRuntime {
  const _ResolvedRuntime({required this.selection, required this.sourceDir});

  final RuntimeSelection selection;
  final String sourceDir;
}
