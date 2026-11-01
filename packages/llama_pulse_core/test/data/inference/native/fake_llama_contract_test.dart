import 'dart:ffi' as ffi;

import 'package:llama_pulse_core/src/data/inference/native/llama_bindings.dart';
import 'package:llama_pulse_core/src/data/inference/native/llama_library.dart';
import 'package:test/test.dart';

import '../../../support/native/fake_llama_builder.dart';

/// Drives the shim's `llama_batch_init`/`llama_decode` directly, without the
/// session, to prove the contract guards reject a malformed batch instead of
/// silently producing output.
void main() {
  late String libraryPath;
  late FakeLlama fake;
  late LlamaBindings bindings;
  String? skipReason;

  setUpAll(() async {
    if (!await FakeLlamaBuilder.isAvailable) {
      skipReason = 'clang is not installed; the native shim needs a compiler';
      return;
    }
    libraryPath = await FakeLlamaBuilder.build();
    fake = FakeLlama(libraryPath);

    final library = await LlamaLibrary.open(libraryPath);
    expect(library.isUsable, isTrue, reason: '${library.failure?.message}');
    bindings = library.bindings;
  });

  setUp(() {
    if (skipReason != null) {
      return;
    }
    fake.reset();
    fake.setVersion('0.8.0');
  });

  int decodeWith(void Function(LlamaBatch batch) configure) {
    final batch = bindings.llamaBatchInit(2, 0, 1);
    try {
      batch.nTokens = 1;
      batch.token[0] = 5;
      batch.pos[0] = 0;
      batch.nSeqId[0] = 1;
      batch.seqId[0][0] = 0;
      batch.logits[0] = 1;
      configure(batch);
      return bindings.llamaDecode(ffi.nullptr, batch);
    } finally {
      bindings.llamaBatchFree(batch);
    }
  }

  test('a well-formed batch decodes', () {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    expect(decodeWith((_) {}), 0);
    expect(fake.contractViolationCount, 0);
    expect(fake.logitsCount, 1);
    expect(fake.logitsLastOnly, isTrue);
  });

  test('a wrong n_seq_id is a contract violation', () {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final result = decodeWith((batch) => batch.nSeqId[0] = 2);

    expect(result, -2);
    expect(fake.contractViolationCount, 1);
  });

  test('a non-zero seq_id is a contract violation', () {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final result = decodeWith((batch) => batch.seqId[0][0] = 1);

    expect(result, -2);
    expect(fake.contractViolationCount, 1);
  });

  test('a non-increasing position is a contract violation', () {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final result = decodeWith((batch) {
      batch.nTokens = 2;
      batch.token[1] = 6;
      batch.pos[0] = 1;
      batch.pos[1] = 1;
      batch.nSeqId[1] = 1;
      batch.seqId[1][0] = 0;
      batch.logits[0] = 0;
      batch.logits[1] = 1;
    });

    expect(result, -2);
    expect(fake.contractViolationCount, 1);
  });

  test('an empty batch is a contract violation', () {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final result = decodeWith((batch) => batch.nTokens = 0);

    expect(result, -2);
    expect(fake.contractViolationCount, 1);
  });
}
