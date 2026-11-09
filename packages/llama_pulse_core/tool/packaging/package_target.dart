import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;

/// Archive format written next to the staging tree.
enum ArchiveKind {
  /// `.tar.gz`, used on Linux.
  tarGz('.tar.gz'),

  /// `.zip`, used on Windows and macOS.
  zip('.zip');

  const ArchiveKind(this.extension);

  /// Suffix appended to the archive name, including the dot.
  final String extension;
}

/// One operating system the packaging tool can build a bundle for.
///
/// Architecture is a separate input because the same OS can run on more than
/// one CPU family. [artifactId], [runtimePlatform] and [stageName] take the
/// architecture string produced by `archFromAbi()`.
enum PackageTarget {
  /// Linux desktop, `.tar.gz` archive.
  linux(os: 'linux', archiveKind: ArchiveKind.tarGz),

  /// Windows desktop, `.zip` archive.
  windows(os: 'windows', archiveKind: ArchiveKind.zip),

  /// macOS application bundle, `.zip` archive.
  macos(os: 'macos', archiveKind: ArchiveKind.zip);

  const PackageTarget({required this.os, required this.archiveKind});

  /// Stable OS identifier used in artifact names and CLI flags.
  final String os;

  /// Archive format this target ships.
  final ArchiveKind archiveKind;

  /// Main executable name inside the bundle.
  String get executableName =>
      this == PackageTarget.windows ? 'llama_pulse.exe' : 'llama_pulse';

  /// Runtime server executable name for this target.
  String get runtimeExecutableName =>
      this == PackageTarget.windows ? 'llama-server.exe' : 'llama-server';

  /// Runtime platform identifier for [arch], or null when LlamaPulse has no
  /// pinned runtime asset for this OS/architecture pair.
  ///
  /// Runtime assets exist only for `linux-x64`, `windows-x64` and
  /// `macos-arm64`; `macos-x64` and `linux-arm64` desktop bundles can still be
  /// packaged without a bundled runtime.
  RuntimePlatform? runtimePlatform(String arch) {
    if (arch == 'arm64' && this == PackageTarget.macos) {
      return RuntimePlatform.macosArm64;
    }
    if (arch != 'x64') {
      return null;
    }
    return switch (this) {
      PackageTarget.linux => RuntimePlatform.linuxX64,
      PackageTarget.windows => RuntimePlatform.windowsX64,
      PackageTarget.macos => null,
    };
  }

  /// Artifact identifier, for example `linux-x64` or `macos-arm64`.
  String artifactId(String arch) => '$os-$arch';

  /// Default Flutter release output for this target.
  String defaultBundleDir(String repoRoot) {
    final app = p.join(repoRoot, 'apps', 'llama_pulse');
    return switch (this) {
      PackageTarget.linux => p.join(
        app,
        'build',
        'linux',
        'x64',
        'release',
        'bundle',
      ),
      PackageTarget.windows => p.join(
        app,
        'build',
        'windows',
        'x64',
        'runner',
        'Release',
      ),
      PackageTarget.macos => p.join(
        app,
        'build',
        'macos',
        'Build',
        'Products',
        'Release',
        'llama_pulse.app',
      ),
    };
  }

  /// Directory the managed runtime is copied into inside [stage].
  ///
  /// macOS keeps it in the app bundle's resources directory; the other
  /// platforms put it beside the executable. Both match the roots the
  /// application resolves at launch.
  String runtimeDirectoryInStage(
    String stage, {
    required String tag,
    required String backend,
  }) {
    final root = this == PackageTarget.macos
        ? p.join(stage, 'llama_pulse.app', 'Contents', 'Resources')
        : stage;
    return p.join(root, 'runtime', tag, backend);
  }
}
