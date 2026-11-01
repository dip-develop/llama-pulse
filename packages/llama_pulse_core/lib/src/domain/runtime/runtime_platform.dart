/// The host operating system and architecture a llama.cpp build targets.
///
/// Only the platforms the pinned release actually ships archives for are
/// listed; there is no generic fallback.
enum RuntimePlatform {
  /// 64-bit Linux on x86-64.
  linuxX64('linux-x64'),

  /// Apple silicon macOS.
  macosArm64('macos-arm64'),

  /// 64-bit Windows on x86-64.
  windowsX64('windows-x64');

  const RuntimePlatform(this.id);

  /// Stable wire string used in configuration, CLI flags and the runtime store.
  final String id;

  /// Whether this platform uses Windows binary and library naming.
  bool get isWindows => this == RuntimePlatform.windowsX64;

  /// Whether this platform uses macOS binary and library naming.
  bool get isMacos => this == RuntimePlatform.macosArm64;

  /// File extension upstream appends to an archive name for this platform.
  ///
  /// The pinned release ships `.tar.gz` for Linux and macOS and `.zip` for
  /// Windows.
  String get archiveExtension => isWindows ? '.zip' : '.tar.gz';

  /// Name of the `llama-server` executable inside an extracted archive.
  String get serverBinaryName =>
      isWindows ? 'llama-server.exe' : 'llama-server';

  /// Name of the main `llama.cpp` shared library for this platform.
  String get libraryFileName => sharedLibraryName('llama');

  /// The platform's file name for the shared library whose base name is [stem].
  ///
  /// `ggml-cuda` becomes `libggml-cuda.so` on Linux, `libggml-cuda.dylib` on
  /// macOS and `ggml-cuda.dll` on Windows.
  String sharedLibraryName(String stem) => switch (this) {
    RuntimePlatform.linuxX64 => 'lib$stem.so',
    RuntimePlatform.macosArm64 => 'lib$stem.dylib',
    RuntimePlatform.windowsX64 => '$stem.dll',
  };

  /// Looks up a platform by its [id], or returns null when unknown.
  static RuntimePlatform? fromId(String id) {
    for (final platform in values) {
      if (platform.id == id) {
        return platform;
      }
    }
    return null;
  }
}
