import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  final catalogOrder = [
    for (final spec in ParameterCatalog.v080.parameters) spec.id,
  ];

  group('set and remove', () {
    test('sets and replaces a value', () {
      final first = ParameterValues.set(
        BuiltMap<String, String>(),
        'temp',
        '0.8',
      );
      final second = ParameterValues.set(first, 'temp', '0.5');

      expect(second['temp'], '0.5');
    });

    test('a null value removes the entry', () {
      final values = BuiltMap<String, String>({'temp': '0.8'});

      expect(ParameterValues.set(values, 'temp', null), isEmpty);
    });

    test('removes a missing id without touching the rest', () {
      final values = BuiltMap<String, String>({'temp': '0.8'});

      expect(ParameterValues.remove(values, 'top-k'), values);
    });

    test('never mutates the input', () {
      final values = BuiltMap<String, String>({'temp': '0.8'});

      ParameterValues.set(values, 'top-k', '10');
      ParameterValues.remove(values, 'temp');

      expect(values.toMap(), {'temp': '0.8'});
    });
  });

  group('normalized', () {
    test('follows catalog order regardless of insertion order', () {
      final first = BuiltMap<String, String>({
        'chat-template': 'a',
        'temp': '0.5',
        'ctx-size': '1024',
      });
      final second = BuiltMap<String, String>({
        'ctx-size': '1024',
        'chat-template': 'a',
        'temp': '0.5',
      });

      final expected = [
        for (final id in catalogOrder)
          if (first.containsKey(id)) id,
      ];
      expect(ParameterValues.normalized(first).keys.toList(), expected);
      expect(
        ParameterValues.normalized(second).keys.toList(),
        ParameterValues.normalized(first).keys.toList(),
      );
    });

    test('keeps unknown ids at the end, sorted', () {
      final values = BuiltMap<String, String>({
        'zzz-unknown': 'z',
        'temp': '0.5',
        'aaa-unknown': 'a',
      });

      final normalized = ParameterValues.normalized(values);

      expect(normalized.keys.toList(), [
        for (final id in catalogOrder)
          if (values.containsKey(id)) id,
        'aaa-unknown',
        'zzz-unknown',
      ]);
      expect(normalized['aaa-unknown'], 'a');
    });

    test('drops nothing', () {
      final values = BuiltMap<String, String>({
        'temp': '0.5',
        'unknown': 'kept',
      });

      expect(ParameterValues.normalized(values).length, values.length);
    });
  });

  group('modifiedIds', () {
    test('reports non-default ids in catalog order', () {
      final values = BuiltMap<String, String>({
        'top-k': '40',
        'temp': '0.5',
        'ctx-size': '2048',
      });

      final modified = ParameterValues.modifiedIds(
        values,
        isDefault: (id, value) => switch (id) {
          'temp' => value == '0.8',
          'top-k' => value == '40',
          'ctx-size' => value == '2048',
          _ => false,
        },
      );

      expect(modified, ['temp']);
    });
  });

  group('ownerOf', () {
    test('resolves a typed owner', () {
      expect(ParameterValues.ownerOf('ctx-size'), 'contextSize');
      expect(ParameterValues.ownerOf('model'), 'modelPath');
    });

    test('returns null for a configurable parameter', () {
      expect(ParameterValues.ownerOf('temp'), isNull);
    });

    test('returns null for an unknown id', () {
      expect(ParameterValues.ownerOf('unknown'), isNull);
    });
  });

  group('valueFor', () {
    test('prefers the typed field over the map', () {
      final config = ServerConfig.defaults().copyWith(
        contextSize: 8192,
        params: BuiltMap<String, String>({'ctx-size': '1'}),
      );

      expect(ParameterValues.valueFor(config, 'ctx-size'), '8192');
    });

    test('falls back to the map for a configurable parameter', () {
      final config = ServerConfig.defaults().copyWith(
        params: BuiltMap<String, String>({'chat-template': '{{prompt}}'}),
      );

      expect(ParameterValues.valueFor(config, 'chat-template'), '{{prompt}}');
    });

    test('returns null when neither source has a value', () {
      expect(ParameterValues.valueFor(ServerConfig.defaults(), 'temp'), isNull);
    });

    test('formats a number and an enum', () {
      final config = ServerConfig.defaults().copyWith(port: 9090);

      expect(ParameterValues.valueFor(config, 'port'), '9090');
      expect(ParameterValues.valueFor(config, 'flash-attn'), 'auto');
    });
  });

  group('valueForModel', () {
    test('prefers the typed sampling field over the map', () {
      final params = ModelParams.defaults().copyWith(
        temperature: 0.5,
        params: BuiltMap<String, String>({'temp': '1.5'}),
      );

      expect(ParameterValues.valueForModel(params, 'temp'), '0.5');
    });

    test('maps every typed sampling field', () {
      final params = ModelParams.defaults();

      expect(ParameterValues.valueForModel(params, 'ctx-size'), '2048');
      expect(ParameterValues.valueForModel(params, 'top-k'), '40');
      expect(ParameterValues.valueForModel(params, 'temp'), '0.8');
      expect(ParameterValues.valueForModel(params, 'max-tokens'), isNull);
      expect(ParameterValues.valueForModel(params, 'predict'), '256');
    });

    test('falls back to the map', () {
      final params = ModelParams.defaults().copyWith(
        params: BuiltMap<String, String>({'seed': '42'}),
      );

      expect(ParameterValues.valueForModel(params, 'seed'), '42');
    });
  });
}
