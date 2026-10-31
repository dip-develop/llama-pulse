import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:llama_pulse_core/src/data/inference/native/llama_library.dart';
import 'package:llama_pulse_core/src/data/inference/native/native_llama_session.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../support/native/fake_llama_builder.dart';

void main() {
  late String libraryPath;
  late FakeLlama fake;
  late Directory temp;
  String? skipReason;

  setUpAll(() async {
    if (!await FakeLlamaBuilder.isAvailable) {
      skipReason = 'clang is not installed; the native shim needs a compiler';
      return;
    }
    libraryPath = await FakeLlamaBuilder.build();
    fake = FakeLlama(libraryPath);
  });

  setUp(() {
    if (skipReason != null) {
      return;
    }
    fake.reset();
    fake.setVersion('0.8.0');
    temp = Directory.systemTemp.createTempSync('llama_pulse_open_');
  });

  tearDown(() {
    if (skipReason != null) {
      return;
    }
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('the pinned version opens once and reports itself', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final first = await LlamaLibrary.open(libraryPath);
    expect(first.isUsable, isTrue);
    expect(first.failure, isNull);
    expect(first.version, '0.8.0');
    expect(first.path, libraryPath);
    expect(first.bindings.llamaVersion, isNotNull);
    final firstInitCount = fake.backendInitCount;
    expect(firstInitCount, greaterThanOrEqualTo(1));

    final second = await LlamaLibrary.open(libraryPath);
    expect(second.isUsable, isTrue);
    expect(
      fake.backendInitCount,
      firstInitCount,
      reason: 'backend init is process-global',
    );
  });

  group('version mismatch', () {
    for (final actual in ['0.7.0-dev', '0.8.0-dev', 'b11960', '']) {
      test('"$actual" is rejected with the reported version', () async {
        if (skipReason != null) {
          markTestSkipped(skipReason!);
          return;
        }

        fake.setVersion(actual);

        final library = await LlamaLibrary.open(libraryPath);

        expect(library.isUsable, isFalse);
        final failure = library.failure;
        expect(failure, isNotNull);
        expect(failure!.code, InferenceFailureCode.libraryVersionMismatch);
        expect(failure.details, isNotNull);
        expect(failure.details, contains(actual));
        expect(failure.message, contains(actual.isEmpty ? '""' : actual));
        expect(fake.backendInitCount, 0);
      });
    }
  });

  group('unopenable paths', () {
    test('a missing library is libraryNotFound', () async {
      if (skipReason != null) {
        markTestSkipped(skipReason!);
        return;
      }

      final missing = p.join(temp.path, 'missing', 'libllama.so');

      final library = await LlamaLibrary.open(missing);

      expect(library.isUsable, isFalse);
      expect(library.failure!.code, InferenceFailureCode.libraryNotFound);
      expect(library.failure!.message, contains(missing));
      expect(library.failure!.details, isNotNull);
    });

    test('an empty path is libraryNotFound', () async {
      if (skipReason != null) {
        markTestSkipped(skipReason!);
        return;
      }

      final library = await LlamaLibrary.open('');

      expect(library.failure!.code, InferenceFailureCode.libraryNotFound);
      expect(library.failure!.message, 'library path is empty');
    });

    test('a relative path is libraryNotFound', () async {
      if (skipReason != null) {
        markTestSkipped(skipReason!);
        return;
      }

      final library = await LlamaLibrary.open('libllama.so');

      expect(library.failure!.code, InferenceFailureCode.libraryNotFound);
      expect(library.failure!.message, 'library path must be absolute');
    });
  });

  group('session', () {
    test('load after a failed open reports the searched path', () async {
      if (skipReason != null) {
        markTestSkipped(skipReason!);
        return;
      }

      final missing = p.join(temp.path, 'missing', 'libllama.so');
      final session = NativeLlamaSession(libraryPath: missing);
      await session.open(missing);

      await expectLater(
        session.load(ModelParams.defaults()),
        throwsA(
          isA<InferenceFailureException>()
              .having(
                (exception) => exception.failure.code,
                'code',
                InferenceFailureCode.libraryNotFound,
              )
              .having(
                (exception) => exception.failure.message,
                'message',
                contains(missing),
              ),
        ),
      );
    });

    test('dispose after a failed open is safe and repeatable', () async {
      if (skipReason != null) {
        markTestSkipped(skipReason!);
        return;
      }

      final session = NativeLlamaSession(
        libraryPath: p.join(temp.path, 'missing', 'libllama.so'),
      );
      await session.open(p.join(temp.path, 'missing', 'libllama.so'));

      await session.dispose();
      await session.dispose();
    });

    test('cancel after a failed open returns normally', () async {
      if (skipReason != null) {
        markTestSkipped(skipReason!);
        return;
      }

      final session = NativeLlamaSession(
        libraryPath: p.join(temp.path, 'missing', 'libllama.so'),
      );

      await session.cancel();
    });
  });
}
