import 'package:llama_pulse/app/platform/clipboard_service.dart';

/// [ClipboardService] that records what was copied instead of using the
/// platform channel.
final class FakeClipboardService implements ClipboardService {
  /// Texts passed to [setText], in call order.
  final List<String> texts = [];

  /// Number of times [setText] was called.
  int calls = 0;

  /// Last text written, or `null` when nothing was copied.
  String? get lastText => texts.isEmpty ? null : texts.last;

  @override
  Future<void> setText(String text) async {
    calls++;
    texts.add(text);
  }
}
