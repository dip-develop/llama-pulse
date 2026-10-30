import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:llama_pulse_core/src/data/config/yaml_decoder.dart';
import 'package:test/test.dart';

void main() {
  final goldenMap = <String, Object?>{
    'schemaVersion': 1,
    'params': <String, Object?>{
      'modelPath': '/models/llama-3.2-3b-instruct.Q4_K_M.gguf',
      'contextSize': 2048,
      'gpuLayers': 0,
      'threads': 4,
      'temperature': 0.8,
      'topP': 0.95,
      'topK': 40,
      'maxTokens': 256,
    },
  };

  const golden =
      'schemaVersion: 1\n'
      'params:\n'
      '  modelPath: /models/llama-3.2-3b-instruct.Q4_K_M.gguf\n'
      '  contextSize: 2048\n'
      '  gpuLayers: 0\n'
      '  threads: 4\n'
      '  temperature: 0.8\n'
      '  topP: 0.95\n'
      '  topK: 40\n'
      '  maxTokens: 256\n';

  test('encodes the params document to the golden bytes', () {
    expect(YamlEncoder.encode(goldenMap), golden);
  });

  group('quoting', () {
    const cases = <String, String>{
      '': "''",
      ' padded ': "' padded '",
      'a: b': "'a: b'",
      '#x': "'#x'",
      'true': "'true'",
      'yes': "'yes'",
      'null': "'null'",
      '007': "'007'",
      '1.0': "'1.0'",
      "it's": "'it''s'",
      '-x': "'-x'",
      'x #c': "'x #c'",
      'plain': 'plain',
    };

    for (final entry in cases.entries) {
      test('quotes ${entry.key}', () {
        expect(YamlEncoder.encode({'v': entry.key}), 'v: ${entry.value}\n');
      });
    }
  });

  test('round-trips double and int without losing the type', () {
    final encoded = YamlEncoder.encode({'double': 1.0, 'int': 1});
    final decoded = YamlDecoder.decode(encoded);

    expect(decoded['double'], isA<double>());
    expect(decoded['double'], 1.0);
    expect(decoded['int'], isA<int>());
    expect(decoded['int'], 1);
  });

  test('encodes a list of maps', () {
    final value = <String, Object?>{
      'items': <Object?>[
        <String, Object?>{'name': 'a', 'value': 1},
        <String, Object?>{'name': 'b', 'value': 2},
      ],
    };

    final encoded = YamlEncoder.encode(value);
    expect(
      encoded,
      'items:\n'
      '  - name: a\n'
      '    value: 1\n'
      '  - name: b\n'
      '    value: 2\n',
    );
    expect(YamlDecoder.decode(encoded), value);
  });

  test('preserves insertion order', () {
    final encoded = YamlEncoder.encode(<String, Object?>{
      'z': 1,
      'a': 2,
      'm': 3,
    });
    expect(encoded, 'z: 1\na: 2\nm: 3\n');
  });

  test('rejects non-finite doubles', () {
    expect(() => YamlEncoder.encode({'v': double.nan}), throwsArgumentError);
    expect(
      () => YamlEncoder.encode({'v': double.infinity}),
      throwsArgumentError,
    );
  });

  test('rejects unsupported nested values and names the path', () {
    expect(
      () => YamlEncoder.encode(<String, Object?>{
        'params': <String, Object?>{
          'values': <Object?>[DateTime(2020)],
        },
      }),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.toString(),
          'message',
          contains('params.values[0]'),
        ),
      ),
    );
  });
}
