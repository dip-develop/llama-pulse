/// Reassembles UTF-8 code points split across token pieces.
///
/// `llama_token_to_piece` can return a partial byte sequence, so token bytes
/// are buffered until a whole code point is available. Invalid and overlong
/// sequences are replaced with U+FFFD rather than decoded.
final class Utf8TokenAccumulator {
  /// Creates an empty accumulator.
  Utf8TokenAccumulator();

  final List<int> _buffer = <int>[];

  /// Appends [bytes]; an empty list is ignored.
  void add(List<int> bytes) {
    if (bytes.isEmpty) {
      return;
    }
    _buffer.addAll(bytes);
  }

  /// Returns complete code points decoded so far, or `null` when nothing
  /// complete is buffered.
  ///
  /// A trailing partial code point stays buffered and is never emitted here.
  String? takeDecoded() {
    if (_buffer.isEmpty) {
      return null;
    }
    final decoded = _decode(flush: false);
    return decoded.isEmpty ? null : decoded;
  }

  /// Returns the remainder of the buffer, replacing invalid bytes with U+FFFD,
  /// and clears it.
  String flush() => _decode(flush: true);

  String _decode({required bool flush}) {
    final output = StringBuffer();
    var index = 0;
    while (index < _buffer.length) {
      final lead = _buffer[index];
      final length = _sequenceLength(lead);
      if (length == 1) {
        output.writeCharCode(lead);
        index++;
        continue;
      }
      if (length == 0) {
        output.writeCharCode(0xFFFD);
        index++;
        continue;
      }
      final available = _buffer.length - index;
      if (available < length) {
        if (!_hasValidPrefix(index, length, available)) {
          output.writeCharCode(0xFFFD);
          index++;
          continue;
        }
        if (!flush) {
          break;
        }
        output.writeCharCode(0xFFFD);
        index = _buffer.length;
        continue;
      }
      if (!_isValidSequence(index, length)) {
        output.writeCharCode(0xFFFD);
        index++;
        continue;
      }
      output.writeCharCode(_codePoint(index, length));
      index += length;
    }
    if (index > 0) {
      _buffer.removeRange(0, index);
    }
    return output.toString();
  }

  // Returns the sequence length implied by [lead], `0` when it is invalid.
  int _sequenceLength(int lead) {
    if (lead <= 0x7F) {
      return 1;
    }
    if (lead >= 0xC2 && lead <= 0xDF) {
      return 2;
    }
    if (lead >= 0xE0 && lead <= 0xEF) {
      return 3;
    }
    if (lead >= 0xF0 && lead <= 0xF4) {
      return 4;
    }
    return 0;
  }

  bool _hasValidPrefix(int index, int length, int available) {
    for (var offset = 1; offset < available; offset++) {
      if (!_isValidContinuation(
        _buffer[index],
        offset,
        _buffer[index + offset],
      )) {
        return false;
      }
    }
    return true;
  }

  bool _isValidSequence(int index, int length) {
    for (var offset = 1; offset < length; offset++) {
      if (!_isValidContinuation(
        _buffer[index],
        offset,
        _buffer[index + offset],
      )) {
        return false;
      }
    }
    return true;
  }

  bool _isValidContinuation(int lead, int offset, int byte) {
    if (byte < 0x80 || byte > 0xBF) {
      return false;
    }
    if (offset != 1) {
      return true;
    }
    return switch (lead) {
      0xE0 => byte >= 0xA0,
      0xED => byte <= 0x9F,
      0xF0 => byte >= 0x90,
      0xF4 => byte <= 0x8F,
      _ => true,
    };
  }

  int _codePoint(int index, int length) {
    final b0 = _buffer[index];
    final b1 = _buffer[index + 1];
    return switch (length) {
      2 => ((b0 & 0x1F) << 6) | (b1 & 0x3F),
      3 =>
        ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (_buffer[index + 2] & 0x3F),
      _ =>
        ((b0 & 0x07) << 18) |
            ((b1 & 0x3F) << 12) |
            ((_buffer[index + 2] & 0x3F) << 6) |
            (_buffer[index + 3] & 0x3F),
    };
  }
}
