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
}
