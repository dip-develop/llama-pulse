import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

ModelParams _params({
  int contextSize = 4096,
  Map<String, String> values = const {},
}) => ModelParams.defaults().copyWith(
  contextSize: contextSize,
  params: BuiltMap<String, String>(values),
);

void main() {
  group('defaults', () {
    test('an empty catalog map keeps the previous hardcoded behaviour', () {
      final runtime = EmbeddedRuntimeConfig.resolve(_params());

      expect(runtime.minP, 0.05);
      expect(runtime.seed, 0xFFFFFFFF);
      expect(runtime.batchSize, 512);
    });

    test('a context below the batch cap bounds the default batch', () {
      final runtime = EmbeddedRuntimeConfig.resolve(_params(contextSize: 128));

      expect(runtime.batchSize, 128);
    });
  });

  group('batch-size', () {
    test('an explicit value is used for both logical and micro batches', () {
      final runtime = EmbeddedRuntimeConfig.resolve(
        _params(values: {'batch-size': '256'}),
      );

      expect(runtime.batchSize, 256);
    });

    test('a value above the default cap is kept below the context', () {
      final runtime = EmbeddedRuntimeConfig.resolve(
        _params(contextSize: 4096, values: {'batch-size': '600'}),
      );

      expect(runtime.batchSize, 600);
    });

    test('a value above the context is clamped to the context', () {
      final runtime = EmbeddedRuntimeConfig.resolve(
        _params(contextSize: 512, values: {'batch-size': '8192'}),
      );

      expect(runtime.batchSize, 512);
    });

    for (final raw in ['0', '-4', 'many']) {
      test('"$raw" falls back to the default', () {
        final runtime = EmbeddedRuntimeConfig.resolve(
          _params(values: {'batch-size': raw}),
        );

        expect(runtime.batchSize, 512);
      });
    }
  });

  group('min-p', () {
    for (final (raw, expected) in [('0', 0.0), ('0.2', 0.2), ('1', 1.0)]) {
      test('"$raw" resolves to $expected', () {
        final runtime = EmbeddedRuntimeConfig.resolve(
          _params(values: {'min-p': raw}),
        );

        expect(runtime.minP, expected);
      });
    }

    for (final raw in ['1.5', '-0.1', 'many']) {
      test('"$raw" falls back to 0.05', () {
        final runtime = EmbeddedRuntimeConfig.resolve(
          _params(values: {'min-p': raw}),
        );

        expect(runtime.minP, 0.05);
      });
    }
  });

  group('seed', () {
    test('a fixed seed is passed through', () {
      final runtime = EmbeddedRuntimeConfig.resolve(
        _params(values: {'seed': '42'}),
      );

      expect(runtime.seed, 42);
    });

    test('-1 means LLAMA_DEFAULT_SEED, which llama.cpp treats as random', () {
      final runtime = EmbeddedRuntimeConfig.resolve(
        _params(values: {'seed': '-1'}),
      );

      expect(runtime.seed, 0xFFFFFFFF);
    });

    test('a value above the uint32 range is clamped', () {
      final runtime = EmbeddedRuntimeConfig.resolve(
        _params(values: {'seed': '4294967296'}),
      );

      expect(runtime.seed, 0xFFFFFFFF);
    });

    test('a negative value below -1 is clamped to zero', () {
      final runtime = EmbeddedRuntimeConfig.resolve(
        _params(values: {'seed': '-5'}),
      );

      expect(runtime.seed, 0);
    });

    test('an unparseable value falls back to the random seed', () {
      final runtime = EmbeddedRuntimeConfig.resolve(
        _params(values: {'seed': 'many'}),
      );

      expect(runtime.seed, 0xFFFFFFFF);
    });
  });
}
