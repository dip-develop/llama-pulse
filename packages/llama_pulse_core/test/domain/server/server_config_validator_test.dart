import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  const validator = ServerConfigValidator();

  ServerConfig withModel([ServerConfig? config]) =>
      (config ?? ServerConfig.defaults()).copyWith(
        modelPath: '/models/llama-3.2-3b.Q4_K_M.gguf',
      );

  group('validate', () {
    test('accepts the defaults', () {
      expect(validator.validate(ServerConfig.defaults()), isEmpty);
    });

    test('accepts a fully populated configuration', () {
      final config = withModel(
        ServerConfig.defaults().copyWith(
          extraArgs: BuiltList<String>(['--verbose', '--no-warmup']),
          binaryPath: '/opt/llama.cpp/llama-server',
        ),
      );

      expect(validator.validate(config), isEmpty);
    });

    test('accepts an empty model path', () {
      expect(
        validator.validate(ServerConfig.defaults().copyWith(modelPath: '')),
        isEmpty,
      );
    });

    test('rejects a whitespace-only model path', () {
      final config = ServerConfig.defaults().copyWith(modelPath: '   ');

      expect(validator.validate(config), ['modelPath must not be blank']);
    });

    test('rejects a model path with a control character', () {
      final config = ServerConfig.defaults().copyWith(
        modelPath: '/models/llama\x7f.gguf',
      );

      expect(validator.validate(config), [
        'modelPath must not contain control characters',
      ]);
    });

    test('rejects an empty host', () {
      final config = ServerConfig.defaults().copyWith(host: '');

      expect(validator.validate(config), ['host must be set']);
    });

    test('rejects a host with whitespace', () {
      final config = ServerConfig.defaults().copyWith(host: '127.0.0.1 ');

      expect(validator.validate(config), ['host must not contain whitespace']);
    });

    test('rejects a host with a slash', () {
      final config = ServerConfig.defaults().copyWith(host: '0.0.0.0/8');

      expect(validator.validate(config), ['host must not contain /']);
    });

    test('rejects a host with a control character', () {
      final config = ServerConfig.defaults().copyWith(host: '127.0.0.1\x00');

      expect(validator.validate(config), [
        'host must not contain control characters',
      ]);
    });

    test('rejects a host longer than 255 characters', () {
      final config = ServerConfig.defaults().copyWith(host: 'a' * 256);

      expect(validator.validate(config), [
        'host must be at most 255 characters',
      ]);
    });

    test('accepts a 255-character host', () {
      final config = ServerConfig.defaults().copyWith(host: 'a' * 255);

      expect(validator.validate(config), isEmpty);
    });

    test('rejects a port outside 1..65535', () {
      for (final port in [0, -1, 65536]) {
        expect(
          validator.validate(ServerConfig.defaults().copyWith(port: port)),
          ['port must be in 1..65535'],
          reason: '$port',
        );
      }
    });

    test('accepts the port bounds', () {
      for (final port in [1, 65535]) {
        expect(
          validator.validate(ServerConfig.defaults().copyWith(port: port)),
          isEmpty,
          reason: '$port',
        );
      }
    });

    test('rejects a context size outside 128..1048576', () {
      for (final size in [127, 1048577]) {
        expect(
          validator.validate(
            ServerConfig.defaults().copyWith(contextSize: size),
          ),
          ['contextSize must be in 128..1048576'],
          reason: '$size',
        );
      }
    });

    test('rejects a thread count outside 1..256', () {
      for (final threads in [0, 257]) {
        expect(
          validator.validate(
            ServerConfig.defaults().copyWith(threads: threads),
          ),
          ['threads must be in 1..256'],
          reason: '$threads',
        );
      }
    });

    test('rejects a GPU layer count outside 0..999', () {
      for (final layers in [-1, 1000]) {
        expect(
          validator.validate(
            ServerConfig.defaults().copyWith(gpuLayers: layers),
          ),
          ['gpuLayers must be in 0..999'],
          reason: '$layers',
        );
      }
    });

    test('rejects a parallel slot count outside 1..64', () {
      for (final slots in [0, 65]) {
        expect(
          validator.validate(
            ServerConfig.defaults().copyWith(parallelSlots: slots),
          ),
          ['parallelSlots must be in 1..64'],
          reason: '$slots',
        );
      }
    });

    test('rejects an alias longer than 128 characters', () {
      final config = ServerConfig.defaults().copyWith(modelAlias: 'a' * 129);

      expect(validator.validate(config), [
        'modelAlias must be at most 128 characters',
      ]);
    });

    test('accepts a 128-character alias', () {
      final config = ServerConfig.defaults().copyWith(modelAlias: 'a' * 128);

      expect(validator.validate(config), isEmpty);
    });

    test('rejects an alias with a control character', () {
      final config = ServerConfig.defaults().copyWith(modelAlias: 'a\x01b');

      expect(validator.validate(config), [
        'modelAlias must not contain control characters',
      ]);
    });

    test('rejects an api key longer than 4096 characters', () {
      final config = ServerConfig.defaults().copyWith(apiKey: 'a' * 4097);

      expect(validator.validate(config), [
        'apiKey must be at most 4096 characters',
      ]);
    });

    test('rejects an api key containing a line break', () {
      for (final apiKey in ['a\nb', 'a\rb']) {
        expect(
          validator.validate(ServerConfig.defaults().copyWith(apiKey: apiKey)),
          ['apiKey must not contain line breaks'],
          reason: apiKey,
        );
      }
    });

    test('rejects more than 64 extra arguments', () {
      final config = ServerConfig.defaults().copyWith(
        extraArgs: BuiltList<String>(List.filled(65, '--verbose')),
      );

      expect(validator.validate(config), [
        'extraArgs must contain at most 64 items',
      ]);
    });

    test('accepts 64 extra arguments', () {
      final config = ServerConfig.defaults().copyWith(
        extraArgs: BuiltList<String>(List.filled(64, '--verbose')),
      );

      expect(validator.validate(config), isEmpty);
    });

    test('rejects an empty extra argument', () {
      final config = ServerConfig.defaults().copyWith(
        extraArgs: BuiltList<String>(['']),
      );

      expect(validator.validate(config), [
        'extraArgs must contain 1..1024 characters per item',
      ]);
    });

    test('rejects an extra argument longer than 1024 characters', () {
      final config = ServerConfig.defaults().copyWith(
        extraArgs: BuiltList<String>(['a' * 1025]),
      );

      expect(validator.validate(config), [
        'extraArgs must contain 1..1024 characters per item',
      ]);
    });

    test('rejects an extra argument with a control character', () {
      final config = ServerConfig.defaults().copyWith(
        extraArgs: BuiltList<String>(['--x\tvalue']),
      );

      expect(validator.validate(config), [
        'extraArgs must not contain control characters',
      ]);
    });

    test('rejects every managed flag in extraArgs', () {
      for (final flag in ServerConfigValidator.managedFlags) {
        final config = ServerConfig.defaults().copyWith(
          extraArgs: BuiltList<String>(['--verbose', flag]),
        );

        expect(validator.validate(config), [
          '$flag is managed by the server configuration',
        ], reason: flag);
      }
    });

    test('rejects managed flags in flag=value form', () {
      for (final argument in <String>[
        '--model=/models/x.gguf',
        '--api-key=secret',
        '--port=1',
        '-m=x',
        '--metrics=true',
      ]) {
        final flag = argument.split('=').first;
        final config = withModel().copyWith(
          extraArgs: BuiltList<String>([argument]),
        );

        expect(validator.validate(config), [
          '$flag is managed by the server configuration',
        ], reason: argument);
      }
    });

    test('accepts unmanaged flags in flag=value form', () {
      final config = withModel().copyWith(
        extraArgs: BuiltList<String>(['--verbose=true', '--chat-template=x']),
      );

      expect(validator.validate(config), isEmpty);
    });

    test('rejects a binary path with a control character', () {
      final config = ServerConfig.defaults().copyWith(
        binaryPath: '/opt/llama\x00-server',
      );

      expect(validator.validate(config), [
        'binaryPath must not contain control characters',
      ]);
    });

    test('rejects a startup timeout outside 10..600', () {
      for (final seconds in [9, 601]) {
        expect(
          validator.validate(
            ServerConfig.defaults().copyWith(startupTimeoutSeconds: seconds),
          ),
          ['startupTimeoutSeconds must be in 10..600'],
          reason: '$seconds',
        );
      }
    });

    test('accepts the startup timeout bounds', () {
      for (final seconds in [10, 600]) {
        expect(
          validator.validate(
            ServerConfig.defaults().copyWith(startupTimeoutSeconds: seconds),
          ),
          isEmpty,
          reason: '$seconds',
        );
      }
    });

    test('reports violations in field declaration order', () {
      final config = ServerConfig.defaults().copyWith(
        modelPath: '   ',
        host: '',
        port: 0,
        contextSize: 1,
        threads: 300,
        gpuLayers: 1000,
        parallelSlots: 100,
        modelAlias: 'a\x01',
        apiKey: 'a\nb',
        extraArgs: BuiltList<String>(['--port', '']),
        binaryPath: 'a\x00b',
        startupTimeoutSeconds: 5,
      );

      expect(validator.validate(config), [
        'modelPath must not be blank',
        'host must be set',
        'port must be in 1..65535',
        'contextSize must be in 128..1048576',
        'threads must be in 1..256',
        'gpuLayers must be in 0..999',
        'parallelSlots must be in 1..64',
        'modelAlias must not contain control characters',
        'apiKey must not contain line breaks',
        'extraArgs must contain 1..1024 characters per item',
        '--port is managed by the server configuration',
        'binaryPath must not contain control characters',
        'startupTimeoutSeconds must be in 10..600',
      ]);
    });
  });

  group('validateForStart', () {
    test('accepts a .gguf model', () {
      expect(validator.validateForStart(withModel()), isEmpty);
    });

    test('accepts an uppercase .GGUF suffix', () {
      final config = ServerConfig.defaults().copyWith(
        modelPath: '/models/LLAMA.GGUF',
      );

      expect(validator.validateForStart(config), isEmpty);
    });

    test('requires a model path', () {
      expect(validator.validateForStart(ServerConfig.defaults()), [
        'modelPath must be set',
      ]);
    });

    test('rejects a model path without the .gguf suffix', () {
      final config = ServerConfig.defaults().copyWith(
        modelPath: '/models/llama.bin',
      );

      expect(validator.validateForStart(config), [
        'modelPath must point to a .gguf file',
      ]);
    });

    test('keeps the violations from validate', () {
      final config = ServerConfig.defaults().copyWith(port: 0);

      expect(validator.validateForStart(config), [
        'port must be in 1..65535',
        'modelPath must be set',
      ]);
    });
  });
}
