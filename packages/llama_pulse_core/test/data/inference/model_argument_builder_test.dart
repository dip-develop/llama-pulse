import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

const _builder = ModelArgumentBuilder();

ModelParams _params({
  String modelPath = '',
  int contextSize = 2048,
  int gpuLayers = 0,
  int threads = 4,
  double temperature = 0.8,
  double topP = 0.95,
  int topK = 40,
  int maxTokens = 256,
  Map<String, String> params = const {},
}) => ModelParams(
  (b) => b
    ..modelPath = modelPath
    ..contextSize = contextSize
    ..gpuLayers = gpuLayers
    ..threads = threads
    ..temperature = temperature
    ..topP = topP
    ..topK = topK
    ..maxTokens = maxTokens
    ..params.replace(BuiltMap<String, String>(params)),
);

const _typedBlock = [
  '-c',
  '2048',
  '-t',
  '4',
  '-ngl',
  '0',
  '--temp',
  '0.8',
  '--top-k',
  '40',
  '--top-p',
  '0.95',
];

void main() {
  test('emits the typed block for the defaults without a model or batch', () {
    expect(_builder.build(ModelParams.defaults()), _typedBlock);
  });

  test('emits -m first when the model path is set', () {
    expect(_builder.build(_params(modelPath: '/models/model.gguf')), [
      '-m',
      '/models/model.gguf',
      ..._typedBlock,
    ]);
  });

  test('maps every typed sampling field', () {
    expect(
      _builder.build(
        _params(
          contextSize: 8192,
          threads: 8,
          gpuLayers: 12,
          temperature: 0.2,
          topK: 12,
          topP: 0.5,
        ),
      ),
      [
        '-c',
        '8192',
        '-t',
        '8',
        '-ngl',
        '12',
        '--temp',
        '0.2',
        '--top-k',
        '12',
        '--top-p',
        '0.5',
      ],
    );
  });

  group('batch-size', () {
    test('is emitted inside the typed block when stored', () {
      expect(_builder.build(_params(params: {'batch-size': '512'})), [
        ..._typedBlock,
        '-b',
        '512',
      ]);
    });

    test('is skipped when zero', () {
      expect(_builder.build(_params(params: {'batch-size': '0'})), _typedBlock);
    });

    test('is normalized through the codec', () {
      expect(_builder.build(_params(params: {'batch-size': ' 0512 '})), [
        ..._typedBlock,
        '-b',
        '512',
      ]);
    });

    test('rejects a value the codec cannot parse', () {
      expect(
        () => _builder.build(_params(params: {'batch-size': 'many'})),
        throwsArgumentError,
      );
    });
  });

  group('generic parameters', () {
    test('are appended in catalog order after the typed block', () {
      final arguments = _builder.build(
        _params(
          params: {'chat-template': '{{prompt}}', 'min-p': '0.1', 'seed': '42'},
        ),
      );

      expect(arguments, [
        ..._typedBlock,
        '--seed',
        '42',
        '--min-p',
        '0.1',
        '--chat-template',
        '{{prompt}}',
      ]);
    });

    test('ignore map insertion order', () {
      final first = _builder.build(
        _params(params: {'seed': '42', 'min-p': '0.1'}),
      );
      final second = _builder.build(
        _params(params: {'min-p': '0.1', 'seed': '42'}),
      );

      expect(first, second);
    });

    test('skips empty and unknown values', () {
      expect(
        _builder.build(
          _params(params: {'chat-template': '', 'not-in-the-catalog': 'x'}),
        ),
        _typedBlock,
      );
    });

    test('skips ids already covered by the typed block', () {
      expect(
        _builder.build(
          _params(
            params: {
              'temp': '0.1',
              'ctx-size': '4096',
              'threads': '8',
              'gpu-layers': '10',
              'top-k': '3',
              'top-p': '0.4',
            },
          ),
        ),
        _typedBlock,
      );
    });

    test('skips managed, removed and unsupported ids', () {
      expect(
        _builder.build(
          _params(
            params: {
              'load-mode': 'none',
              'defrag-thold': '0.1',
              'warmup': 'true',
            },
          ),
        ),
        _typedBlock,
      );
    });

    test('keeps a value with spaces as one token', () {
      const template = 'a b;c \$d -e';
      final arguments = _builder.build(
        _params(params: {'chat-template': template}),
      );

      expect(arguments, [..._typedBlock, '--chat-template', template]);
    });

    test('rejects a value the codec cannot parse', () {
      expect(
        () => _builder.build(_params(params: {'seed': 'many'})),
        throwsArgumentError,
      );
    });
  });
}
