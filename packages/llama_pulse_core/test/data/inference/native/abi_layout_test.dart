import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart' show calloc;
import 'package:llama_pulse_core/src/data/inference/native/llama_bindings.dart';
import 'package:test/test.dart';

/// Guards the hand-written bindings against the pinned C header.
///
/// `third_party/llama_cpp/v0.8.0/abi_check.c` includes the real `llama.h` and
/// prints every struct size and field offset. This test compiles it with clang,
/// runs it, and compares the output with the layout `dart:ffi` gives the structs
/// in `llama_bindings.dart`.
///
/// `dart:ffi` has no `offsetOf`, so the Dart side is measured: a struct is
/// filled with 0xFF, one field is set to 0, and the index of the first zero byte
/// is that field's offset.
void main() {
  late final Directory repoRoot;
  late final Directory pinDirectory;

  setUpAll(() {
    repoRoot = _findRepoRoot();
    pinDirectory = Directory('${repoRoot.path}/third_party/llama_cpp/v0.8.0');
  });

  group('abi_check.c against llama.h', () {
    late Directory buildDirectory;
    _AbiReport? report;
    String? skipReason;

    setUpAll(() async {
      final source = File('${pinDirectory.path}/abi_check.c');
      final include = Directory('${pinDirectory.path}/include');
      buildDirectory = Directory.systemTemp.createTempSync('llama_pulse_abi_');
      final executable = '${buildDirectory.path}/abi_check';

      try {
        final compile = await Process.run('clang', [
          '-std=c11',
          '-I',
          include.path,
          source.path,
          '-o',
          executable,
        ]);
        if (compile.exitCode != 0) {
          fail(
            'clang could not build abi_check.c (exit ${compile.exitCode}):\n'
            '${compile.stderr}',
          );
        }

        final run = await Process.run(executable, const []);
        if (run.exitCode != 0) {
          fail('abi_check exited with ${run.exitCode}:\n${run.stderr}');
        }
        report = _AbiReport.parse(run.stdout as String);
      } on ProcessException {
        skipReason = 'clang is not installed; the ABI check needs a C compiler';
      }
    });

    tearDownAll(() {
      if (buildDirectory.existsSync()) {
        buildDirectory.deleteSync(recursive: true);
      }
    });

    test('sizes and every field offset match the header', () {
      if (report == null) {
        markTestSkipped(skipReason!);
        return;
      }
      final header = report!;

      for (final name in _expectedStructs) {
        final size = header.sizes[name];
        expect(size, isNotNull, reason: 'abi_check.c did not report $name');
        expect(size, greaterThan(0), reason: '$name must not be empty');
      }

      // Sanity: the batch carries seven pointer-sized members, so it must be
      // larger than a single-bool sampler chain params.
      expect(
        header.sizes['LlamaBatch'],
        greaterThan(header.sizes['LlamaSamplerChainParams']!),
        reason: 'LlamaBatch should be larger than LlamaSamplerChainParams',
      );

      // ---------------------------------------------------------------------
      // LlamaModelParams <- struct llama_model_params
      // ---------------------------------------------------------------------
      const modelParams = 'LlamaModelParams';
      final modelParamsSize = ffi.sizeOf<LlamaModelParams>();
      _expectSize(header, modelParams, modelParamsSize);
      _expectOffset(
        header,
        modelParams,
        'devices',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.devices = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'tensorBuftOverrides',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.tensorBuftOverrides =
              ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'nGpuLayers',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.nGpuLayers = 0,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'splitMode',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.splitMode = 0,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'loadMode',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.loadMode = 0,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'lazyMode',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.lazyMode = 0,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'mainGpu',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.mainGpu = 0,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'tensorSplit',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.tensorSplit = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'progressCallback',
        _probeOffset(
          modelParamsSize,
          (raw) =>
              raw.cast<LlamaModelParams>().ref.progressCallback = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'progressCallbackUserData',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.progressCallbackUserData =
              ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'kvOverrides',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.kvOverrides = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'vocabOnly',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.vocabOnly = false,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'checkTensors',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.checkTensors = false,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'useExtraBufts',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.useExtraBufts = false,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'noHost',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.noHost = false,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'noAlloc',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.noAlloc = false,
        ),
      );
      _expectOffset(
        header,
        modelParams,
        'loadMtp',
        _probeOffset(
          modelParamsSize,
          (raw) => raw.cast<LlamaModelParams>().ref.loadMtp = false,
        ),
      );

      // ---------------------------------------------------------------------
      // LlamaContextParams <- struct llama_context_params
      // ---------------------------------------------------------------------
      const contextParams = 'LlamaContextParams';
      final contextParamsSize = ffi.sizeOf<LlamaContextParams>();
      _expectSize(header, contextParams, contextParamsSize);
      _expectOffset(
        header,
        contextParams,
        'nCtx',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.nCtx = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'nBatch',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.nBatch = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'nUbatch',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.nUbatch = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'nSeqMax',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.nSeqMax = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'nRsSeq',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.nRsSeq = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'nOutputsMax',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.nOutputsMax = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'nOutputsMaxPerSeq',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.nOutputsMaxPerSeq = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'nThreads',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.nThreads = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'nThreadsBatch',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.nThreadsBatch = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'ctxType',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.ctxType = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'ropeScalingType',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.ropeScalingType = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'poolingType',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.poolingType = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'attentionType',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.attentionType = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'flashAttnType',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.flashAttnType = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'ropeFreqBase',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.ropeFreqBase = 0.0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'ropeFreqScale',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.ropeFreqScale = 0.0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'yarnExtFactor',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.yarnExtFactor = 0.0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'yarnAttnFactor',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.yarnAttnFactor = 0.0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'yarnBetaFast',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.yarnBetaFast = 0.0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'yarnBetaSlow',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.yarnBetaSlow = 0.0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'yarnOrigCtx',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.yarnOrigCtx = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'defragThold',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.defragThold = 0.0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'cbEval',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.cbEval = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'cbEvalUserData',
        _probeOffset(
          contextParamsSize,
          (raw) =>
              raw.cast<LlamaContextParams>().ref.cbEvalUserData = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'typeK',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.typeK = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'typeV',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.typeV = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'moeCacheSize',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.moeCacheSize = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'abortCallback',
        _probeOffset(
          contextParamsSize,
          (raw) =>
              raw.cast<LlamaContextParams>().ref.abortCallback = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'abortCallbackData',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.abortCallbackData =
              ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'embeddings',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.embeddings = false,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'offloadKqv',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.offloadKqv = false,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'noPerf',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.noPerf = false,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'opOffload',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.opOffload = false,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'swaFull',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.swaFull = false,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'kvUnified',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.kvUnified = false,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'samplers',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.samplers = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'nSamplers',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.nSamplers = 0,
        ),
      );
      _expectOffset(
        header,
        contextParams,
        'ctxOther',
        _probeOffset(
          contextParamsSize,
          (raw) => raw.cast<LlamaContextParams>().ref.ctxOther = ffi.nullptr,
        ),
      );

      // ---------------------------------------------------------------------
      // LlamaBatch <- struct llama_batch
      // ---------------------------------------------------------------------
      const batch = 'LlamaBatch';
      final batchSize = ffi.sizeOf<LlamaBatch>();
      _expectSize(header, batch, batchSize);
      _expectOffset(
        header,
        batch,
        'nTokens',
        _probeOffset(
          batchSize,
          (raw) => raw.cast<LlamaBatch>().ref.nTokens = 0,
        ),
      );
      _expectOffset(
        header,
        batch,
        'token',
        _probeOffset(
          batchSize,
          (raw) => raw.cast<LlamaBatch>().ref.token = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        batch,
        'embd',
        _probeOffset(
          batchSize,
          (raw) => raw.cast<LlamaBatch>().ref.embd = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        batch,
        'pos',
        _probeOffset(
          batchSize,
          (raw) => raw.cast<LlamaBatch>().ref.pos = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        batch,
        'nSeqId',
        _probeOffset(
          batchSize,
          (raw) => raw.cast<LlamaBatch>().ref.nSeqId = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        batch,
        'seqId',
        _probeOffset(
          batchSize,
          (raw) => raw.cast<LlamaBatch>().ref.seqId = ffi.nullptr,
        ),
      );
      _expectOffset(
        header,
        batch,
        'logits',
        _probeOffset(
          batchSize,
          (raw) => raw.cast<LlamaBatch>().ref.logits = ffi.nullptr,
        ),
      );

      // ---------------------------------------------------------------------
      // LlamaSamplerChainParams <- struct llama_sampler_chain_params
      // ---------------------------------------------------------------------
      const chainParams = 'LlamaSamplerChainParams';
      final chainParamsSize = ffi.sizeOf<LlamaSamplerChainParams>();
      _expectSize(header, chainParams, chainParamsSize);
      _expectOffset(
        header,
        chainParams,
        'noPerf',
        _probeOffset(
          chainParamsSize,
          (raw) => raw.cast<LlamaSamplerChainParams>().ref.noPerf = false,
        ),
      );

      // ---------------------------------------------------------------------
      // LlamaPerfContextData <- struct llama_perf_context_data
      // ---------------------------------------------------------------------
      const perfData = 'LlamaPerfContextData';
      final perfDataSize = ffi.sizeOf<LlamaPerfContextData>();
      _expectSize(header, perfData, perfDataSize);
      _expectOffset(
        header,
        perfData,
        'tStartMs',
        _probeOffset(
          perfDataSize,
          (raw) => raw.cast<LlamaPerfContextData>().ref.tStartMs = 0.0,
        ),
      );
      _expectOffset(
        header,
        perfData,
        'tLoadMs',
        _probeOffset(
          perfDataSize,
          (raw) => raw.cast<LlamaPerfContextData>().ref.tLoadMs = 0.0,
        ),
      );
      _expectOffset(
        header,
        perfData,
        'tPEvalMs',
        _probeOffset(
          perfDataSize,
          (raw) => raw.cast<LlamaPerfContextData>().ref.tPEvalMs = 0.0,
        ),
      );
      _expectOffset(
        header,
        perfData,
        'tEvalMs',
        _probeOffset(
          perfDataSize,
          (raw) => raw.cast<LlamaPerfContextData>().ref.tEvalMs = 0.0,
        ),
      );
      _expectOffset(
        header,
        perfData,
        'nPEval',
        _probeOffset(
          perfDataSize,
          (raw) => raw.cast<LlamaPerfContextData>().ref.nPEval = 0,
        ),
      );
      _expectOffset(
        header,
        perfData,
        'nEval',
        _probeOffset(
          perfDataSize,
          (raw) => raw.cast<LlamaPerfContextData>().ref.nEval = 0,
        ),
      );
      _expectOffset(
        header,
        perfData,
        'nReused',
        _probeOffset(
          perfDataSize,
          (raw) => raw.cast<LlamaPerfContextData>().ref.nReused = 0,
        ),
      );
      _expectOffset(
        header,
        perfData,
        'nReallocsSame',
        _probeOffset(
          perfDataSize,
          (raw) => raw.cast<LlamaPerfContextData>().ref.nReallocsSame = 0,
        ),
      );
      _expectOffset(
        header,
        perfData,
        'nReallocsDiff',
        _probeOffset(
          perfDataSize,
          (raw) => raw.cast<LlamaPerfContextData>().ref.nReallocsDiff = 0,
        ),
      );

      // Canary: abi_check.c always reports 72 offsets (17 + 38 + 7 + 1 + 9).
      // A change here means a field was added to or removed from the header
      // and the Dart struct needs the same change.
      expect(
        header.offsets.length,
        72,
        reason:
            'abi_check.c reported a different number of fields; '
            'update llama_bindings.dart together with the pin',
      );
    });
  });
}

const _expectedStructs = [
  'LlamaModelParams',
  'LlamaContextParams',
  'LlamaBatch',
  'LlamaSamplerChainParams',
  'LlamaPerfContextData',
];

void _expectSize(_AbiReport header, String name, int dartSize) {
  final headerSize = header.sizes[name];
  expect(headerSize, isNotNull, reason: 'abi_check.c did not report $name');
  expect(
    dartSize,
    headerSize,
    reason: '$name: header $headerSize, Dart $dartSize',
  );
}

void _expectOffset(
  _AbiReport header,
  String name,
  String field,
  int dartOffset,
) {
  final key = '$name.${_snakeCase(field)}';
  final headerOffset = header.offsets[key];
  expect(headerOffset, isNotNull, reason: 'abi_check.c did not report $key');
  expect(
    dartOffset,
    headerOffset,
    reason: '$name.$field: header $headerOffset, Dart $dartOffset',
  );
}

/// Returns the offset of the field that [zero] clears to 0.
///
/// The struct is filled with 0xFF first, so the first zero byte after clearing a
/// single field is that field's offset.
int _probeOffset(int size, void Function(ffi.Pointer<ffi.Uint8> raw) zero) {
  final memory = calloc<ffi.Uint8>(size);
  try {
    final bytes = memory.asTypedList(size)..fillRange(0, size, 0xFF);
    zero(memory);
    for (var index = 0; index < size; index++) {
      if (bytes[index] == 0) {
        return index;
      }
    }
    fail('the probed field did not write to the struct');
  } finally {
    calloc.free(memory);
  }
}

/// `nGpuLayers` -> `n_gpu_layers`, so abi_check.c's C field names can be looked
/// up from the Dart field names used in the failure messages.
String _snakeCase(String camel) {
  final buffer = StringBuffer();
  for (var index = 0; index < camel.length; index++) {
    final unit = camel.codeUnitAt(index);
    final isUpper = unit >= 0x41 && unit <= 0x5A;
    if (isUpper && index > 0) {
      final previous = camel.codeUnitAt(index - 1);
      final previousIsUpper = previous >= 0x41 && previous <= 0x5A;
      final nextIsLower =
          index + 1 < camel.length &&
          camel.codeUnitAt(index + 1) >= 0x61 &&
          camel.codeUnitAt(index + 1) <= 0x7A;
      if (!previousIsUpper || nextIsLower) {
        buffer.write('_');
      }
    }
    buffer.writeCharCode(isUpper ? unit + 0x20 : unit);
  }
  return buffer.toString();
}

/// The output of `abi_check.c`.
final class _AbiReport {
  _AbiReport(this.sizes, this.offsets);

  final Map<String, int> sizes;

  /// Keyed by `<Struct>.<c_field_name>`.
  final Map<String, int> offsets;

  static _AbiReport parse(String output) {
    final sizes = <String, int>{};
    final offsets = <String, int>{};

    for (final line in output.split('\n')) {
      final parts = line.trim().split(' ');
      if (parts.length == 3 && parts[0] == 'size') {
        sizes[parts[1]] = _parseInt(line, parts[2]);
      } else if (parts.length == 4 && parts[0] == 'off') {
        offsets['${parts[1]}.${parts[2]}'] = _parseInt(line, parts[3]);
      } else if (line.trim().isNotEmpty) {
        fail('unparseable abi_check line: "$line"');
      }
    }
    return _AbiReport(sizes, offsets);
  }

  static int _parseInt(String line, String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      fail('unparseable number in abi_check line: "$line"');
    }
    return parsed;
  }
}

Directory _findRepoRoot() {
  var directory = Directory.current.absolute;
  while (true) {
    if (File('${directory.path}/third_party/llama_cpp/v0.8.0/abi_check.c')
        .existsSync()) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      fail(
        'third_party/llama_cpp/v0.8.0/abi_check.c not found above '
        '${Directory.current.path}',
      );
    }
    directory = parent;
  }
}
