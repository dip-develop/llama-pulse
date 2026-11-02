import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('llama_pulse_locator_');
  });

  tearDown(() {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  String touch(String relative) {
    final file = File(p.join(temp.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('');
    return file.path;
  }

  LlamaLibraryLocator locator({
    String? explicitPath,
    Map<String, String> environment = const {},
    String operatingSystem = 'linux',
    String? executablePath,
    String? configDirectory,
  }) => LlamaLibraryLocator(
    explicitPath: explicitPath,
    environment: environment,
    operatingSystem: operatingSystem,
    executablePath: executablePath ?? p.join(temp.path, 'bin', 'llamapulse'),
    configDirectory: configDirectory ?? p.join(temp.path, 'config'),
  );

  String exeDir() => p.join(temp.path, 'bin');

  group('libraryFileName', () {
    test('follows the operating system', () {
      expect(locator(operatingSystem: 'linux').libraryFileName, 'libllama.so');
      expect(
        locator(operatingSystem: 'macos').libraryFileName,
        'libllama.dylib',
      );
      expect(locator(operatingSystem: 'windows').libraryFileName, 'llama.dll');
    });
  });

  group('candidates', () {
    test('lists every step in order', () {
      final explicit = p.join(temp.path, 'explicit', 'libllama.so');
      final env = p.join(temp.path, 'env', 'libllama.so');
      final binary = p.join(exeDir(), 'libllama.so');

      final paths = locator(
        explicitPath: explicit,
        environment: {'LLAMA_PULSE_LIB': env},
        executablePath: p.join(exeDir(), 'llamapulse'),
        configDirectory: p.join(temp.path, 'config'),
      ).candidates;

      expect(paths, [
        explicit,
        env,
        p.join(exeDir(), 'lib', 'libllama.so'),
        binary,
        p.join(temp.path, 'Frameworks', 'libllama.so'),
        p.join(temp.path, 'config', 'lib', 'libllama.so'),
        'libllama.so',
      ]);
    });

    test('explicit path wins over the environment', () {
      final explicit = p.join(temp.path, 'explicit', 'libllama.so');
      final env = p.join(temp.path, 'env', 'libllama.so');

      final paths = locator(
        explicitPath: explicit,
        environment: {'LLAMA_PULSE_LIB': env},
      ).candidates;

      expect(paths.first, explicit);
      expect(paths[1], env);
    });

    test('a missing explicit path is still the first candidate', () {
      final explicit = p.join(temp.path, 'missing', 'libllama.so');

      final paths = locator(explicitPath: explicit).candidates;

      expect(paths.first, explicit);
      expect(File(explicit).existsSync(), isFalse);
    });

    test('resolves a relative explicit path against the current directory', () {
      final paths = locator(explicitPath: p.join('relative', 'libllama.so'))
          .candidates;

      expect(
        paths.first,
        p.normalize(p.join(Directory.current.path, 'relative', 'libllama.so')),
      );
    });

    test('rejects an empty explicit path', () {
      expect(() => locator(explicitPath: '  '), throwsArgumentError);
    });

    test('keeps the bare file name last', () {
      final paths = locator().candidates;

      expect(paths.last, 'libllama.so');
    });

    test('removes duplicates while preserving order', () {
      final shared = p.join(temp.path, 'shared', 'libllama.so');

      final paths = locator(
        explicitPath: shared,
        environment: {'LLAMA_PULSE_LIB': shared},
      ).candidates;

      expect(paths.where((path) => path == shared), hasLength(1));
      expect(paths.first, shared);
      expect(paths[1], isNot(shared));
    });

    test('ignores an empty environment value', () {
      final paths = locator(environment: {'LLAMA_PULSE_LIB': '   '}).candidates;

      expect(paths.first, p.join(exeDir(), 'lib', 'libllama.so'));
    });

    test('uses the injected OS file name at every step', () {
      final paths = locator(operatingSystem: 'macos').candidates;

      expect(paths, everyElement(endsWith('libllama.dylib')));
    });
  });

  group('resolveExisting', () {
    test('returns null when no candidate exists', () {
      expect(locator().resolveExisting(), isNull);
    });

    test('returns the first existing candidate', () {
      final env = touch(p.join('env', 'libllama.so'));
      touch(p.join('bin', 'lib', 'libllama.so'));

      final found = locator(environment: {'LLAMA_PULSE_LIB': env})
          .resolveExisting();

      expect(found, env);
    });

    test('does not check the bare file name', () {
      expect(locator().candidates.last, 'libllama.so');
      expect(locator().resolveExisting(), isNull);
    });

    test('finds a config-directory library', () {
      final config = p.join(temp.path, 'config');
      final library = touch(p.join('config', 'lib', 'libllama.so'));

      expect(locator(configDirectory: config).resolveExisting(), library);
    });
  });

  group('runtime installs', () {
    void writeIndex(RuntimeIndex index) {
      final body =
          serializers.serializeWith(RuntimeIndex.serializer, index)!
              as Map<String, Object?>;
      File(p.join(temp.path, 'config', 'runtime', 'index.yaml'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          YamlEncoder.encode(<String, Object?>{
            'schemaVersion': RuntimeIndex.schemaVersion,
            ...body,
          }),
        );
    }

    RuntimeIndex indexWith({
      String? selectedTag,
      RuntimeBackend? selectedBackend,
      List<(RuntimeBackend, int)> installed = const [
        (RuntimeBackend.cuda13, 20),
        (RuntimeBackend.cpu, 30),
      ],
    }) => RuntimeIndex(
      (b) => b
        ..selectedTag = selectedTag ?? ''
        ..selectedBackend = selectedBackend
        ..installed = BuiltList<RuntimeInstallRef>(<RuntimeInstallRef>[
          for (final (backend, installedAt) in installed)
            RuntimeInstallRef(
              (r) => r
                ..tag = 'v0.8.0'
                ..backend = backend
                ..platform = RuntimePlatform.linuxX64
                ..installedAtEpochMs = installedAt
                ..sizeBytes = 1,
            ),
        ]).toBuilder(),
    );

    test('selected runtime comes before config/lib', () {
      writeIndex(
        indexWith(selectedTag: 'v0.8.0', selectedBackend: RuntimeBackend.cpu),
      );

      final paths = locator(configDirectory: p.join(temp.path, 'config'))
          .candidates;

      final selectedPath = p.join(
        temp.path,
        'config',
        'runtime',
        'v0.8.0',
        'cpu',
        'libllama.so',
      );
      final otherPath = p.join(
        temp.path,
        'config',
        'runtime',
        'v0.8.0',
        'cuda13',
        'libllama.so',
      );
      final legacyPath = p.join(temp.path, 'config', 'lib', 'libllama.so');
      expect(paths.indexOf(selectedPath), greaterThanOrEqualTo(0));
      expect(paths.indexOf(otherPath), paths.indexOf(selectedPath) + 1);
      expect(paths.indexOf(legacyPath), paths.indexOf(otherPath) + 1);
    });

    test('without a selection the newest install comes first', () {
      writeIndex(indexWith());

      final paths = locator(configDirectory: p.join(temp.path, 'config'))
          .candidates;

      final runtimePaths = paths
          .where((path) => path.contains(p.join('runtime', 'v0.8.0')))
          .toList();
      expect(runtimePaths, hasLength(2));
      expect(runtimePaths.first, contains(p.join('v0.8.0', 'cpu')));
      expect(runtimePaths.last, contains(p.join('v0.8.0', 'cuda13')));
    });

    test('a missing index adds no runtime candidates', () {
      final paths = locator(configDirectory: p.join(temp.path, 'config'))
          .candidates;

      expect(paths.where((path) => path.contains('runtime')), isEmpty);
    });

    test('resolveExisting finds a runtime library', () {
      writeIndex(indexWith());
      final library = touch(
        p.join('config', 'runtime', 'v0.8.0', 'cpu', 'libllama.so'),
      );

      expect(
        locator(configDirectory: p.join(temp.path, 'config')).resolveExisting(),
        library,
      );
    });
  });

  group('notFoundFailure', () {
    test('lists every candidate one per line', () {
      final failure = locator().notFoundFailure();

      expect(failure.code, InferenceFailureCode.libraryNotFound);
      expect(failure.details, isNotNull);
      final lines = failure.details!.split('\n');
      expect(lines, locator().candidates);
      expect(failure.message, contains('libllama.so'));
      expect(failure.message, contains('LLAMA_PULSE_LIB'));
    });
  });

  group('LlamaVersionPin', () {
    test('matches the pinned version, ignoring whitespace', () {
      expect(LlamaVersionPin.matches('0.8.0'), isTrue);
      expect(LlamaVersionPin.matches('  0.8.0\n'), isTrue);
      expect(LlamaVersionPin.matches('0.8.0-dev'), isFalse);
      expect(LlamaVersionPin.matches('0.7.0'), isFalse);
    });

    test('describes a mismatch with both versions', () {
      final failure = LlamaVersionPin.mismatch('0.7.0-dev');

      expect(failure.code, InferenceFailureCode.libraryVersionMismatch);
      expect(failure.message, 'expected llama.cpp 0.8.0, found "0.7.0-dev"');
    });
  });

  group('InferenceFailureCode', () {
    test('round-trips the native library codes', () {
      final codes = [
        InferenceFailureCode.libraryNotFound,
        InferenceFailureCode.libraryVersionMismatch,
      ];

      expect(InferenceFailureCode.values, containsAll(codes));
      for (final code in codes) {
        expect(
          serializers.serializeWith(InferenceFailureCode.serializer, code),
          code.name,
        );
        expect(
          serializers.deserializeWith(
            InferenceFailureCode.serializer,
            code.name,
          ),
          code,
        );
        expect(InferenceFailureCode.valueOf(code.name), code);
      }
    });
  });
}
