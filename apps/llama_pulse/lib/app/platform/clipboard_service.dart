import 'package:flutter/services.dart';

/// Writes text to the system clipboard.
///
/// Injected so widget tests can assert what was copied without the platform
/// channel behind [Clipboard] being available.
abstract interface class ClipboardService {
  /// Replaces the clipboard contents with [text].
  Future<void> setText(String text);
}

/// [ClipboardService] backed by Flutter's platform clipboard.
final class SystemClipboardService implements ClipboardService {
  /// Creates a service that talks to the platform clipboard.
  const SystemClipboardService();

  @override
  Future<void> setText(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}
