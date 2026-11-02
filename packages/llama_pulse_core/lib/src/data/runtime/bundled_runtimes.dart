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
/// The layout mirrors `<config>/runtime/` so the same archive can be copied
/// into either place. Bundled runtimes are not in `index.yaml`; when a bundle
/// carries more than one, the loaders try them in reverse path order, which is
/// deterministic even though no install time exists. A runtime the user
/// selected under `<config>/runtime/` always wins over a bundled one.
abstract final class BundledRuntimes {
  /// Name of the runtime directory inside the application bundle.
  static const String directoryName = 'runtime';

  /// `<executableDirectory>/runtime`, whether or not it exists.
  static String rootFor(String executableDirectory) =>
      p.join(executableDirectory, directoryName);

  /// Every `<tag>/<backend>` directory under [executableDirectory], reverse
  /// path order.
  ///
  /// Returns an empty list when the bundle has no runtime directory. Unreadable
  /// entries are skipped: a broken bundle must never stop a launch.
  static List<String> directories(String executableDirectory) {
    final root = Directory(rootFor(executableDirectory));
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
            found.add(p.normalize(backendEntry.path));
          }
        }
      }
    } on FileSystemException {
      return const <String>[];
    } on UnsupportedError {
      return const <String>[];
    }
    found.sort((a, b) => b.compareTo(a));
    return List<String>.unmodifiable(found);
  }
}
