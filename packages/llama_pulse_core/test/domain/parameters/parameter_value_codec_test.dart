import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

ParameterSpec _spec(String id) {
  final spec = ParameterCatalog.v080.byId(id);
  if (spec == null) {
    throw StateError('missing catalog parameter $id');
  }
  return spec;
}

void main() {
  final boolean = _spec('swa-full');
  final integer = _spec('top-k');
  final unsigned = _spec('ctx-size');
  final decimal = _spec('temp');
  final enumeration = _spec('pooling');
  final path = _spec('grammar-file');
  final text = _spec('chat-template');
  final list = _spec('dry-sequence-breaker');
  final repeatable = _spec('lora');
  final pair = _spec('control-vector-layer-range');
  final map = _spec('override-kv');

  group('boolean', () {
    test('canonicalizes every accepted spelling', () {
      for (final raw in ['true', 'TRUE', '1', 'on']) {
        expect(ParameterValueCodec.parse(boolean, raw), 'true', reason: raw);
      }
      for (final raw in ['false', 'FALSE', '0', 'off']) {
        expect(ParameterValueCodec.parse(boolean, raw), 'false', reason: raw);
      }
    });

    test('rejects an unknown spelling', () {
      expect(ParameterValueCodec.validate(boolean, 'yes', forStart: false), [
        '--swa-full must be a boolean (true, false, 1, 0, on or off)',
      ]);
    });

    test('rejects an empty value', () {
      expect(ParameterValueCodec.validate(boolean, '', forStart: false), [
        '--swa-full must be a boolean (true, false, 1, 0, on or off)',
      ]);
    });
  });

  group('integer and decimal', () {
    test('normalizes surrounding whitespace and signs', () {
      expect(ParameterValueCodec.parse(integer, ' 0042 '), '42');
      expect(ParameterValueCodec.parse(integer, '+7'), '7');
    });

    test('rejects a non-integer', () {
      expect(ParameterValueCodec.validate(integer, '1.5', forStart: false), [
        '--top-k must be an integer',
      ]);
    });

    test('rejects an unsigned parameter below zero', () {
      expect(ParameterValueCodec.validate(unsigned, '-1', forStart: false), [
        '--ctx-size must be at least 0',
      ]);
    });

    test('enforces both bounds', () {
      expect(ParameterValueCodec.validate(decimal, '2.5', forStart: false), [
        '--temp must be in 0..2',
      ]);
    });

    test('rejects NaN and infinity', () {
      for (final raw in ['NaN', 'Infinity', '-Infinity']) {
        expect(ParameterValueCodec.validate(decimal, raw, forStart: false), [
          '--temp must be a finite number',
        ], reason: raw);
      }
    });

    test('canonicalizes a decimal', () {
      expect(ParameterValueCodec.parse(decimal, '0.80'), '0.8');
      expect(
        ParameterValueCodec.validate(decimal, '0.80', forStart: false),
        isEmpty,
      );
    });
  });

  group('enumeration', () {
    test('accepts an allowed value exactly', () {
      expect(ParameterValueCodec.parse(enumeration, 'mean'), 'mean');
    });

    test('is case sensitive', () {
      expect(
        ParameterValueCodec.validate(enumeration, 'Mean', forStart: false),
        ['--pooling must be one of: none, mean, cls, last, rank'],
      );
    });
  });

  group('text', () {
    test('rejects control characters and NUL', () {
      for (final raw in ['a\x00b', 'a\tb', 'a\x7fb']) {
        expect(ParameterValueCodec.validate(text, raw, forStart: false), [
          '--chat-template must not contain control characters',
        ], reason: raw.codeUnits.toString());
      }
    });

    test('accepts 4096 characters and rejects 4097', () {
      expect(
        ParameterValueCodec.validate(text, 'a' * 4096, forStart: false),
        isEmpty,
      );
      expect(ParameterValueCodec.validate(text, 'a' * 4097, forStart: false), [
        '--chat-template must be at most 4096 characters',
      ]);
    });

    test('treats empty text as not set', () {
      expect(ParameterValueCodec.parse(text, ''), isNull);
      expect(ParameterValueCodec.validate(text, '', forStart: false), isEmpty);
    });
  });

  group('path', () {
    test('checks existence only for a start with a predicate', () {
      expect(
        ParameterValueCodec.validate(
          path,
          '/models/grammar.gbnf',
          forStart: false,
          pathExists: (_) => false,
        ),
        isEmpty,
      );
      expect(
        ParameterValueCodec.validate(
          path,
          '/models/grammar.gbnf',
          forStart: true,
          pathExists: (value) => value == '/models/grammar.gbnf',
        ),
        isEmpty,
      );
      expect(
        ParameterValueCodec.validate(
          path,
          '/missing.gbnf',
          forStart: true,
          pathExists: (_) => false,
        ),
        ['--grammar-file path does not exist: /missing.gbnf'],
      );
    });
  });

  group('list and pair', () {
    test('rejects a trailing comma', () {
      expect(ParameterValueCodec.validate(list, 'a,b,', forStart: false), [
        '--dry-sequence-breaker must not contain empty list items',
      ]);
    });

    test('canonicalizes comma-separated items', () {
      expect(ParameterValueCodec.parse(list, ' a , b '), 'a,b');
    });

    test('canonicalizes a repeatable newline list', () {
      expect(
        ParameterValueCodec.parse(repeatable, '/a.gguf\n/b.gguf'),
        '/a.gguf\n/b.gguf',
      );
    });

    test('rejects a pair with one value', () {
      expect(ParameterValueCodec.validate(pair, '0.5', forStart: false), [
        '--control-vector-layer-range requires two values separated by a newline',
      ]);
    });

    test('accepts a pair with two newline-separated values', () {
      expect(ParameterValueCodec.parse(pair, '0.5\n0.75'), '0.5\n0.75');
    });

    test('rejects a map entry without an equals sign', () {
      expect(ParameterValueCodec.validate(map, 'a=b\nc', forStart: false), [
        '--override-kv must use key=value entries',
      ]);
      expect(
        ParameterValueCodec.validate(map, 'a=b\nc=d', forStart: false),
        isEmpty,
      );
    });
  });

  group('defaults', () {
    test('formats the canonical default', () {
      expect(ParameterValueCodec.formatDefault(decimal), '0.8');
      expect(ParameterValueCodec.formatDefault(unsigned), '0');
      expect(ParameterValueCodec.formatDefault(boolean), '');
    });

    test('recognizes a default value', () {
      expect(ParameterValueCodec.isDefault(decimal, '0.8'), isTrue);
      expect(ParameterValueCodec.isDefault(decimal, '0.80'), isTrue);
      expect(ParameterValueCodec.isDefault(decimal, '0.5'), isFalse);
      expect(ParameterValueCodec.isDefault(decimal, null), isTrue);
      expect(ParameterValueCodec.isDefault(boolean, null), isTrue);
      expect(ParameterValueCodec.isDefault(boolean, 'true'), isFalse);
    });
  });
}
