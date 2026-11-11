import 'dart:io';

import 'package:path/path.dart' as p;

/// Runtimes that ship inside an application bundle.
///
/// A packaged LlamaPulse can carry one pinned runtime beside the executable:
///
/// ```
/// <exeDir>/runtime/<tag>/<backend>/llama-server
/// <exeDir>/runtime/<tag>/<backend>/libllama.so
/// ```
///
/// A macOS `.app` may instead (or additionally) keep it in the conventional
/// resources directory:
///
/// ```
/// <name>.app/Contents/MacOS/runtime/<tag>/<backend>/...
/// <name>.app/Contents/Resources/runtime/<tag>/<backend>/...
/// ```
///
/// The layout mirrors `<config>/runtime/` so the same archive can be copied
/// into either place. Bundled runtimes are not in `index.yaml`; when a bundle
/// carries more than one, the loaders try them in reverse path order, which is
/// deterministic even though no install time exists. Because `Resources`
/// sorts after `MacOS`, a macOS bundle prefers `Contents/Resources/runtime`
/// over `Contents/MacOS/runtime`. A runtime the user selected under
/// `<config>/runtime/` always wins over a bundled one.
abstract final class BundledRuntimes {
  /// Name of the runtime directory inside the application bundle.
  static const String directoryName = 'runtime';

  /// `<executableDirectory>/runtime`, whether or not it exists.
  static String rootFor(String executableDirectory, {p.Context? pathContext}) =>
      (pathContext ?? p.context).join(executableDirectory, directoryName);

  /// `<executableDirectory>/../Resources/runtime`, whether or not it exists.
  ///
  /// This is `Contents/Resources/runtime` for a macOS executable at
  /// `Contents/MacOS/<name>`.
  static String macOsResourcesRootFor(
    String executableDirectory, {
    p.Context? pathContext,
  }) {
    final path = pathContext ?? p.context;
    return path.normalize(
      path.join(executableDirectory, '..', 'Resources', directoryName),
    );
  }

  /// Every `<tag>/<backend>` directory under the bundle's runtime roots,
  /// reverse path order.
  ///
  /// The roots are `<exeDir>/runtime` and, when [macOsBundle] is set,
  /// `<exeDir>/../Resources/runtime`. Both may exist; duplicates are removed
  /// and the result is sorted reverse path order, so `Contents/Resources`
  /// comes before `Contents/MacOS`.
  ///
  /// Paths are rendered with [pathContext] (the host's context by default).
  /// Tests pass a foreign context to exercise Windows or macOS shapes.
  ///
  /// Returns an empty list when the bundle has no runtime directory. Unreadable
  /// roots and entries are skipped: a broken bundle must never stop a launch.
  static List<String> directories(
    String executableDirectory, {
    bool macOsBundle = false,
    p.Context? pathContext,
  }) {
    final path = pathContext ?? p.context;
    final roots = <String>[
      rootFor(executableDirectory, pathContext: path),
      if (macOsBundle)
        macOsResourcesRootFor(executableDirectory, pathContext: path),
    ];
    final seen = <String>{};
    final found = <String>[];
    for (final rootPath in roots) {
      for (final directory in _backendDirectories(rootPath, path)) {
        if (seen.add(directory)) {
          found.add(directory);
        }
      }
    }
    found.sort((a, b) => b.compareTo(a));
    return List<String>.unmodifiable(found);
  }

  /// Backend directories under a single runtime root, unsorted.
  static List<String> _backendDirectories(String rootPath, p.Context path) {
    final root = Directory(rootPath);
    final found = <String>[];
    try {
      if (!root.existsSync()) {
        return const <String>[];
      }
      for (final tagEntry in root.listSync(followLinks: false)) {
        if (tagEntry is! Directory) {
          continue;
        }
        for (final backendEntry in tagEntry.listSync(followLinks: false)) {
          if (backendEntry is Directory) {
            found.add(path.normalize(backendEntry.path));
          }
        }
      }
    } on FileSystemException {
      return const <String>[];
    } on UnsupportedError {
      return const <String>[];
    }
    return found;
  }
}
