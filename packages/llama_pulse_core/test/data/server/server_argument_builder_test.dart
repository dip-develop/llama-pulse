import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

const _builder = ServerArgumentBuilder();

ServerConfig _config({
  String modelPath = '/models/model.gguf',
  String host = '127.0.0.1',
  int port = 8080,
  int contextSize = 4096,
  int threads = 4,
  int gpuLayers = 0,
  int parallelSlots = 1,
  String modelAlias = 'llama-pulse',
  String apiKey = '',
  ServerFlashAttention flashAttention = ServerFlashAttention.auto,
  bool mlock = false,
  bool mmap = true,
  List<String> extraArgs = const [],
  Map<String, String> params = const {},
}) => ServerConfig(
  (b) => b
    ..modelPath = modelPath
    ..host = host
    ..port = port
    ..contextSize = contextSize
    ..threads = threads
    ..gpuLayers = gpuLayers
    ..parallelSlots = parallelSlots
    ..modelAlias = modelAlias
    ..apiKey = apiKey
    ..flashAttention = flashAttention
    ..mlock = mlock
    ..mmap = mmap
    ..extraArgs.replace(extraArgs)
    ..params.replace(BuiltMap<String, String>(params))
    ..binaryPath = ''
    ..startupTimeoutSeconds = 120,
);

const _base = [
  '-m',
  '/models/model.gguf',
  '--host',
  '127.0.0.1',
  '--port',
  '8080',
  '-c',
  '4096',
  '-t',
  '4',
  '-ngl',
  '0',
  '-np',
  '1',
  '-fa',
  'auto',
  '--metrics',
  '--slots',
];

void main() {
  group('loops over the same arg vector consistently', () {
    test('defaults, loopback host, mlock off and mmap on', () {
      expect(_builder.build(_config(), useLoadMode: false), [
        ..._base,
        '-a',
        'llama-pulse',
      ]);
    });
  });

  test('omits alias and api-key when they are empty', () {
    final arguments = _builder.build(
      _config(modelAlias: '', apiKey: ''),
      useLoadMode: false,
    );

    expect(arguments, _base);
  });

  test('adds alias and api-key when they are set', () {
    final arguments = _builder.build(
      _config(modelAlias: 'demo', apiKey: 'secret'),
      useLoadMode: false,
    );

    expect(arguments, [..._base, '-a', 'demo', '--api-key', 'secret']);
  });

  test('maps flash attention modes', () {
    expect(
      _builder.build(
        _config(modelAlias: '', flashAttention: ServerFlashAttention.on),
        useLoadMode: false,
      ),
      containsAllInOrder(['-fa', 'on']),
    );
    expect(
      _builder.build(
        _config(modelAlias: '', flashAttention: ServerFlashAttention.off),
        useLoadMode: false,
      ),
      containsAllInOrder(['-fa', 'off']),
    );
  });

  group('load mode', () {
    test('mmap only', () {
      expect(_builder.build(_config(modelAlias: ''), useLoadMode: true), [
        ..._base,
        '-lm',
        'mmap',
      ]);
    });

    test('mmap plus mlock', () {
      expect(
        _builder.build(
          _config(modelAlias: '', mmap: true, mlock: true),
          useLoadMode: true,
        ),
        [..._base, '-lm', 'mmap+mlock'],
      );
    });

    test('mlock only', () {
      expect(
        _builder.build(
          _config(modelAlias: '', mmap: false, mlock: true),
          useLoadMode: true,
        ),
        [..._base, '-lm', 'mlock'],
      );
    });

    test('neither', () {
      expect(
        _builder.build(
          _config(modelAlias: '', mmap: false, mlock: false),
          useLoadMode: true,
        ),
        [..._base, '-lm', 'none'],
      );
    });
  });

  group('legacy profile', () {
    test('emits --mlock only when mlock is on', () {
      expect(
        _builder.build(
          _config(modelAlias: '', mmap: true, mlock: true),
          useLoadMode: false,
        ),
        [..._base, '--mlock'],
      );
    });

    test('emits --no-mmap when mmap is off', () {
      expect(
        _builder.build(
          _config(modelAlias: '', mmap: false, mlock: false),
          useLoadMode: false,
        ),
        [..._base, '--no-mmap'],
      );
    });

    test('emits both flags when mlock is on and mmap is off', () {
      expect(
        _builder.build(
          _config(modelAlias: '', mmap: false, mlock: true),
          useLoadMode: false,
        ),
        [..._base, '--mlock', '--no-mmap'],
      );
    });

    test('emits no load flag for the mlock-off mmap-on default', () {
      expect(
        _builder.build(_config(modelAlias: ''), useLoadMode: false),
        _base,
      );
    });
  });

  test('appends extra args last, unchanged', () {
    final arguments = _builder.build(
      _config(
        modelAlias: '',
        extraArgs: ['--verbose', '--chat-template', 'a b c'],
      ),
      useLoadMode: true,
    );

    expect(arguments, [
      ..._base,
      '-lm',
      'mmap',
      '--verbose',
      '--chat-template',
      'a b c',
    ]);
  });

  group('catalog parameters', () {
    test('emits nothing when params is empty', () {
      expect(
        _builder.build(_config(modelAlias: ''), useLoadMode: false),
        _base,
      );
    });

    test('emits one parameter of every supported shape in catalog order', () {
      final arguments = _builder.build(
        _config(
          modelAlias: '',
          params: {
            'top-k': '40',
            'cont-batching': 'true',
            'mmproj': '/models/mmproj.gguf',
            'split-mode': 'row',
            'tensor-split': '3,1',
            'override-kv': 'a=bool:false\nb=int:1',
            'lora': 'a.gguf\nb.gguf',
            'lora-scaled': 'a.gguf\n0.8',
            'control-vector-layer-range': '0\n12',
          },
        ),
        useLoadMode: false,
      );

      expect(arguments, [
        ..._base,
        '--top-k',
        '40',
        '--cont-batching',
        '--mmproj',
        '/models/mmproj.gguf',
        '--split-mode',
        'row',
        '--tensor-split',
        '3,1',
        '--override-kv',
        'a=bool:false',
        '--override-kv',
        'b=int:1',
        '--lora',
        'a.gguf',
        '--lora',
        'b.gguf',
        '--lora-scaled',
        'a.gguf',
        '--lora-scaled',
        '0.8',
        '--control-vector-layer-range',
        '0',
        '12',
      ]);
    });

    test('emits the negated flag for a false boolean', () {
      final arguments = _builder.build(
        _config(modelAlias: '', params: {'cont-batching': 'false'}),
        useLoadMode: false,
      );

      expect(arguments, [..._base, '-nocb']);
    });

    test('skips a false boolean without a negated form and warns', () {
      final warnings = <String>[];
      final builder = ServerArgumentBuilder(onWarning: warnings.add);

      final arguments = builder.build(
        _config(modelAlias: '', params: {'ignore-eos': 'false'}),
        useLoadMode: false,
      );

      expect(arguments, _base);
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('ignore-eos'));
    });

    test('emits a true boolean without a negated form as a bare flag', () {
      final arguments = _builder.build(
        _config(modelAlias: '', params: {'ignore-eos': 'true'}),
        useLoadMode: false,
      );

      expect(arguments, [..._base, '--ignore-eos']);
    });

    test('normalizes values through the codec', () {
      final arguments = _builder.build(
        _config(
          modelAlias: '',
          params: {'top-k': ' 0040 ', 'top-p': '0.90', 'cont-batching': 'ON'},
        ),
        useLoadMode: false,
      );

      expect(arguments, [
        ..._base,
        '--top-k',
        '40',
        '--top-p',
        '0.9',
        '--cont-batching',
      ]);
    });

    test('skips an empty value', () {
      final arguments = _builder.build(
        _config(modelAlias: '', params: {'chat-template': ''}),
        useLoadMode: false,
      );

      expect(arguments, _base);
    });

    test('throws ArgumentError for a value the codec cannot parse', () {
      expect(
        () => _builder.build(
          _config(modelAlias: '', params: {'top-k': 'many'}),
          useLoadMode: false,
        ),
        throwsArgumentError,
      );
    });

    test('skips ids with a typed owner', () {
      final arguments = _builder.build(
        _config(
          modelAlias: '',
          params: {
            'model': '/models/other.gguf',
            'ctx-size': '8192',
            'alias': 'other',
            'extra-args': '--verbose',
          },
        ),
        useLoadMode: false,
      );

      expect(arguments, _base);
    });

    test('skips managed, removed, unsupported and unknown ids', () {
      final arguments = _builder.build(
        _config(
          modelAlias: '',
          params: {
            'load-mode': 'none',
            'defrag-thold': '0.1',
            'warmup': 'true',
            'not-in-the-catalog': 'x',
          },
        ),
        useLoadMode: false,
      );

      expect(arguments, _base);
    });

    test('keeps values with spaces and shell metacharacters as one token', () {
      const template = "a b;c \$d -e 'f' \"g\"";
      final arguments = _builder.build(
        _config(modelAlias: '', params: {'chat-template': template}),
        useLoadMode: false,
      );

      expect(arguments, [..._base, '--chat-template', template]);
      expect(arguments.where((token) => token.contains(template)), [template]);
      expect(arguments.where((token) => token.startsWith('--chat-template')), [
        '--chat-template',
      ]);
    });

    test('ignores the insertion order of the map', () {
      final first = _builder.build(
        _config(
          modelAlias: '',
          params: {'chat-template': '{{prompt}}', 'temp': '0.5'},
        ),
        useLoadMode: false,
      );
      final second = _builder.build(
        _config(
          modelAlias: '',
          params: {'temp': '0.5', 'chat-template': '{{prompt}}'},
        ),
        useLoadMode: false,
      );

      expect(first, second);
    });

    test('follows catalog order, not map insertion order', () {
      final arguments = _builder.build(
        _config(
          modelAlias: '',
          params: {'cont-batching': 'true', 'top-k': '40'},
        ),
        useLoadMode: false,
      );

      expect(arguments, [..._base, '--top-k', '40', '--cont-batching']);
    });

    test('places parameters after the load mode flags', () {
      final config = _config(
        modelAlias: '',
        params: {'top-k': '40'},
        extraArgs: ['--verbose'],
      );

      expect(_builder.build(config, useLoadMode: true), [
        ..._base,
        '-lm',
        'mmap',
        '--top-k',
        '40',
        '--verbose',
      ]);
      expect(_builder.build(config, useLoadMode: false), [
        ..._base,
        '--top-k',
        '40',
        '--verbose',
      ]);
    });
  });
}
