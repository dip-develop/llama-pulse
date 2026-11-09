import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package_target.dart';

/// A managed runtime selected for the bundle.
typedef RuntimeSelection = ({String tag, String backend});

/// Reads the version from `apps/llama_pulse/pubspec.yaml` and drops the
/// `+build` suffix, so `0.1.0+1` becomes `0.1.0`.
///
/// Throws [FormatException] when the text has no `version:` line or the value
/// is not a valid semantic version.
String versionFromPubspecText(String text) {
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('version:')) {
      continue;
    }
    final value = trimmed.substring('version:'.length).trim();
    if (value.isEmpty) {
      throw const FormatException('the version field is empty');
    }
    final withoutBuild = value.split('+').first.trim();
    if (!_versionPattern.hasMatch(withoutBuild)) {
      throw FormatException('invalid version: $value');
    }
    return withoutBuild;
  }
  throw const FormatException('no version field found');
}

final RegExp _versionPattern = RegExp(
  r'^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$',
);

/// Stage directory name, `llama-pulse-<version>-<artifactId>`.
///
/// [arch] defaults to the host architecture from [archFromAbi]; tests pass it
/// explicitly to cover Windows and macOS names on any host.
String stageName(String version, PackageTarget target, {String? arch}) =>
    'llama-pulse-$version-${target.artifactId(arch ?? archFromAbi())}';

/// Archive file name, for example `llama-pulse-0.1.0-linux-x64.tar.gz`.
String archiveName(String version, PackageTarget target, {String? arch}) =>
    '${stageName(version, target, arch: arch)}'
    '${target.archiveKind.extension}';

/// CPU architecture name used in artifact identifiers.
///
/// Returns `x64`, `arm64`, `arm`, `ia32` or `riscv64`. Throws
/// [UnsupportedError] for an ABI this tool does not know.
String archFromAbi() => archNameForAbi(Abi.current());

/// Maps a [Abi] value to the architecture name used in artifact identifiers.
String archNameForAbi(Abi abi) => switch (abi) {
  Abi.linuxX64 || Abi.windowsX64 || Abi.macosX64 => 'x64',
  Abi.linuxArm64 ||
  Abi.windowsArm64 ||
  Abi.macosArm64 ||
  Abi.androidArm64 ||
  Abi.iosArm64 => 'arm64',
  Abi.linuxArm || Abi.androidArm || Abi.iosArm => 'arm',
  Abi.linuxIA32 || Abi.windowsIA32 || Abi.androidIA32 => 'ia32',
  Abi.linuxRiscv64 => 'riscv64',
  _ => throw UnsupportedError('unsupported ABI: $abi'),
};

/// Repo root for a script living at `<repo>/packages/llama_pulse_core/tool`.
///
/// [scriptUri] is normally `Platform.script`; it must be a `file:` URI.
String repoRootFromScript(Uri scriptUri) {
  if (!scriptUri.isScheme('file')) {
    throw ArgumentError.value(
      scriptUri,
      'scriptUri',
      'must be a file URI such as Platform.script',
    );
  }
  final scriptDirectory = p.dirname(p.fromUri(scriptUri));
  return p.normalize(p.join(scriptDirectory, '..', '..', '..'));
}

/// Entries the staging tree must contain for [target], relative to [stage].
///
/// Base entries come from the Flutter release output; `README.md` and
/// `LICENSE` are copied beside it. With [runtime], the managed runtime
/// directory, its server executable and its `runtime.yaml` are included too.
///
/// Directory entries end with `/`. [stage] names the tree the entries belong
/// to and must not be empty; [verifyLayout] joins the result with it.
List<String> requiredEntries(
  PackageTarget target,
  String stage, {
  RuntimeSelection? runtime,
}) {
  if (stage.isEmpty) {
    throw ArgumentError.value(stage, 'stage', 'must not be empty');
  }
  final entries = switch (target) {
    PackageTarget.linux => <String>[
      'llama_pulse',
      'lib/',
      'data/flutter_assets/',
      'README.md',
      'LICENSE',
    ],
    PackageTarget.windows => <String>[
      'llama_pulse.exe',
      'flutter_windows.dll',
      'data/icudtl.dat',
      'data/flutter_assets/',
      'README.md',
      'LICENSE',
    ],
    PackageTarget.macos => <String>[
      'llama_pulse.app/Contents/MacOS/llama_pulse',
      'llama_pulse.app/Contents/Info.plist',
      'llama_pulse.app/Contents/Frameworks/FlutterMacOS.framework/',
      // Flutter bundles macOS assets inside App.framework, not Contents/
      // Resources; `Resources` is a symlink to `Versions/Current/Resources`
      // and verifyLayout follows it.
      'llama_pulse.app/Contents/Frameworks/App.framework/Resources/'
          'flutter_assets/',
      'README.md',
      'LICENSE',
    ],
  };
  if (runtime != null) {
    final directory = p.relative(
      target.runtimeDirectoryInStage(
        stage,
        tag: runtime.tag,
        backend: runtime.backend,
      ),
      from: stage,
    );
    entries.addAll(<String>[
      '$directory/',
      '$directory/${target.runtimeExecutableName}',
      '$directory/runtime.yaml',
    ]);
  }
  return entries;
}

/// Problems found in the tree below [stage], one per missing or invalid entry.
///
/// A missing entry is reported as its absolute path. An entry that exists with
/// the wrong type is reported as `<path> is not a file` or
/// `<path> is not a directory`. Directory entries end with `/` in
/// [requiredEntries]; so does a macOS `.framework` bundle.
///
/// Returns an empty list when the staging tree is complete. This only checks
/// the tree; [stage] and the archive writer own creating it.
List<String> verifyLayout(
  String stage,
  PackageTarget target, {
  RuntimeSelection? runtime,
}) {
  final problems = <String>[];
  for (final entry in requiredEntries(target, stage, runtime: runtime)) {
    final path = _joinEntry(stage, entry);
    final expectedDirectory =
        entry.endsWith('/') || entry.endsWith('.framework/');
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.notFound) {
      problems.add(path);
    } else if (expectedDirectory && type != FileSystemEntityType.directory) {
      problems.add('$path is not a directory');
    } else if (!expectedDirectory &&
        type != FileSystemEntityType.file &&
        type != FileSystemEntityType.link) {
      problems.add('$path is not a file');
    }
  }
  return problems;
}

String _joinEntry(String stage, String entry) {
  final isDirectory = entry.endsWith('/');
  final trimmed = isDirectory ? entry.substring(0, entry.length - 1) : entry;
  // Entries are POSIX-style; split before joining so the reported path uses
  // the host separator throughout instead of mixing `\` and `/` on Windows.
  final joined = p.joinAll(<String>[stage, ...trimmed.split('/')]);
  return isDirectory ? '$joined${p.separator}' : joined;
}
