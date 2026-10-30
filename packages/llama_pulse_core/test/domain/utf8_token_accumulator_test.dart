import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  group('Utf8TokenAccumulator', () {
    test('decodes ASCII', () {
      final accumulator = Utf8TokenAccumulator()
        ..add([0x68, 0x65, 0x6C, 0x6C, 0x6F]);

      expect(accumulator.takeDecoded(), 'hello');
      expect(accumulator.takeDecoded(), isNull);
    });

    test('holds a split 3-byte code point until it is complete', () {
      final accumulator = Utf8TokenAccumulator()..add([0xE2, 0x82]);

      expect(accumulator.takeDecoded(), isNull);

      accumulator.add([0xAC]);

      expect(accumulator.takeDecoded(), '€');
      expect(accumulator.takeDecoded(), isNull);
    });

    test('holds a 4-byte emoji split across three pieces', () {
      final accumulator = Utf8TokenAccumulator()..add([0xF0]);

      expect(accumulator.takeDecoded(), isNull);

      accumulator.add([0x9F, 0x98]);

      expect(accumulator.takeDecoded(), isNull);

      accumulator.add([0x80]);

      expect(accumulator.takeDecoded(), '😀');
      expect(accumulator.takeDecoded(), isNull);
    });

    test('replaces an invalid continuation byte with U+FFFD', () {
      final accumulator = Utf8TokenAccumulator()..add([0xE2, 0x28, 0xA1]);

      expect(accumulator.takeDecoded(), '\uFFFD(\uFFFD');
    });

    test('replaces an overlong sequence with U+FFFD', () {
      final accumulator = Utf8TokenAccumulator()..add([0xC0, 0xAF]);

      expect(accumulator.takeDecoded(), '\uFFFD\uFFFD');
    });

    test('flush emits a truncated tail as U+FFFD and clears the buffer', () {
      final accumulator = Utf8TokenAccumulator()..add([0xE2, 0x82]);

      expect(accumulator.takeDecoded(), isNull);
      expect(accumulator.flush(), '\uFFFD');
      expect(accumulator.flush(), isEmpty);
      expect(accumulator.takeDecoded(), isNull);
    });

    test('takeDecoded never emits a partial code point', () {
      final accumulator = Utf8TokenAccumulator()..add([0x41, 0xF0, 0x9F]);

      expect(accumulator.takeDecoded(), 'A');
      expect(accumulator.takeDecoded(), isNull);
    });

    test('adding an empty list is a no-op', () {
      final accumulator = Utf8TokenAccumulator()
        ..add([])
        ..add([0x7A]);

      expect(accumulator.takeDecoded(), 'z');
      expect(accumulator.takeDecoded(), isNull);
    });
  });
}
