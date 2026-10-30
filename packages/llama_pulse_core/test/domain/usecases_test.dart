import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

final class _FakeRepository implements ModelParamsRepository {
  _FakeRepository(this._loaded);

  final ModelParams _loaded;
  ModelParams? saved;
  int saveCalls = 0;

  @override
  Future<ModelParams> load() async => _loaded;

  @override
  Future<void> save(ModelParams params) async {
    saveCalls++;
    saved = params;
  }
}

final class _FakeScanner implements ModelScanner {
  _FakeScanner({this.found});

  final ModelFileInfo? found;
  Iterable<String>? lastDirectories;
  bool? lastRecursive;
  String? lastInspected;

  @override
  Future<ModelScanResult> scan({
    required Iterable<String> directories,
    bool recursive = false,
  }) async {
    lastDirectories = directories;
    lastRecursive = recursive;
    return const ModelScanResult(files: [], warnings: []);
  }

  @override
  Future<ModelFileInfo?> inspect(String path) async {
    lastInspected = path;
    return found;
  }
}

ModelFileInfo _fileInfo(String path) => ModelFileInfo(
  (b) => b
    ..path = path
    ..fileName = 'a.gguf'
    ..sizeBytes = 10
    ..modifiedAtEpochMs = 0,
);

void main() {
  group('LoadModelParams', () {
    test('delegates to the repository', () async {
      final params = ModelParams.defaults().copyWith(threads: 8);
      final repository = _FakeRepository(params);

      expect(await LoadModelParams(repository)(), same(params));
    });
  });

  group('SaveModelParams', () {
    test(
      'throws before touching the repository when params are invalid',
      () async {
        final repository = _FakeRepository(ModelParams.defaults());
        final useCase = SaveModelParams(
          repository,
          const ModelParamsValidator(),
        );

        await expectLater(
          useCase(ModelParams.defaults().copyWith(contextSize: 0)),
          throwsA(isA<InvalidModelParamsException>()),
        );
        expect(repository.saveCalls, 0);
      },
    );

    test('delegates once for valid params', () async {
      final repository = _FakeRepository(ModelParams.defaults());
      final useCase = SaveModelParams(repository, const ModelParamsValidator());
      final params = ModelParams.defaults().copyWith(threads: 2);

      await useCase(params);

      expect(repository.saveCalls, 1);
      expect(repository.saved, same(params));
    });
  });

  group('ListModels', () {
    test('passes an empty const list when no directories are given', () async {
      final scanner = _FakeScanner();

      await ListModels(scanner)();

      expect(identical(scanner.lastDirectories, const <String>[]), isTrue);
      expect(scanner.lastRecursive, isFalse);
    });

    test('forwards the given directories', () async {
      final scanner = _FakeScanner();
      final directories = ['/models', '/other'];

      await ListModels(scanner)(directories: directories);

      expect(scanner.lastDirectories, same(directories));
    });
  });

  group('InspectModel', () {
    test('returns null for a missing file', () async {
      final scanner = _FakeScanner();

      expect(await InspectModel(scanner)('/missing.gguf'), isNull);
      expect(scanner.lastInspected, '/missing.gguf');
    });

    test('delegates for an existing file', () async {
      final info = _fileInfo('/models/a.gguf');
      final scanner = _FakeScanner(found: info);

      expect(await InspectModel(scanner)('/models/a.gguf'), same(info));
      expect(scanner.lastInspected, '/models/a.gguf');
    });
  });
}
