import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../../../domain/entities/generation_metrics.dart';
import '../../../domain/entities/generation_request.dart';
import '../../../domain/entities/inference_failure.dart';
import '../../../domain/entities/inference_failure_code.dart';
import '../../../domain/entities/model_params.dart';
import '../../../domain/exceptions/inference_failure_exception.dart';
import '../../../domain/gateways/llama_session.dart';
import '../../../domain/text/utf8_token_accumulator.dart';
import '../library_locator.dart';
import 'llama_bindings.dart';
import 'llama_library.dart';

/// The real [LlamaSession], backed by a llama.cpp shared library.
///
/// The library is opened lazily on the first [load], and a failed open is
/// recorded rather than thrown so [load] can report a structured
/// [InferenceFailureException] that includes the resolved library path.
///
/// [next] does one chunk of prompt evaluation or one generated token per call,
/// so a cancellation is observed within one chunk. Prompt chunks that are not
/// the last one are returned as `done: false` steps with empty text, which lets
/// the worker surface progress without inventing output.
final class NativeLlamaSession implements LlamaSession {
  /// Creates a session that will load [libraryPath] on first use.
  // A public name is required here, so an initializing formal would expose the
  // private field as `_libraryPath` and callers could not pass it.
  NativeLlamaSession({required String libraryPath})
    // ignore: prefer_initializing_formals
    : _libraryPath = libraryPath;

  /// The largest batch llama.cpp is given for this app's models.
  static const int _maxBatchSize = 512;

  /// Initial buffer for `llama_token_to_piece`; most pieces fit in it.
  static const int _pieceBufferSize = 64;

  /// `LLAMA_DEFAULT_SEED` from `llama.h`.
  static const int _defaultSeed = 0xFFFFFFFF;

  /// `INT32_MIN`, returned by `llama_tokenize` when the result overflows.
  static const int _int32Min = -0x80000000;

  String _libraryPath;

  /// The opened library, including a cached failure; a failed open is not
  /// retried until the process restarts (intentional).
  LlamaLibrary? _library;

  ffi.Pointer<LlamaModel>? _model;
  ffi.Pointer<LlamaContext>? _context;
  ffi.Pointer<LlamaSampler>? _sampler;

  int? _nCtx;
  int? _nBatch;

  /// Prompt tokens to decode, kept as a Dart list for fast batch filling.
  Int32List _pending = Int32List(0);

  int _position = 0;
  int _generated = 0;
  int _maxTokens = 0;
  int _promptTokenCount = 0;
  bool _active = false;
  bool _cancelled = false;
  bool _finished = false;
  final Stopwatch _stopwatch = Stopwatch();
  Utf8TokenAccumulator _accumulator = Utf8TokenAccumulator();

  /// The library path the session was opened with.
  String get libraryPath => _libraryPath;

  /// `llama_n_ctx` of the loaded context, or null before a successful load.
  int? get contextSize => _nCtx;

  /// `llama_n_batch` of the loaded context, or null before a load.
  int? get batchSize => _nBatch;

  @override
  Future<void> open(String libraryPath) async {
    if (libraryPath != _libraryPath) {
      _release();
      _library = null;
    }
    _libraryPath = libraryPath;
  }

  @override
  Future<void> load(ModelParams params) async {
    if (_libraryPath.trim().isEmpty) {
      // The worker passes an empty path when the locator found nothing; report
      // every searched path instead of a bare "library path is empty".
      throw InferenceFailureException(LlamaLibraryLocator().notFoundFailure());
    }
    final library = await _ensureLibrary();
    final libraryFailure = library.failure;
    if (libraryFailure != null) {
      throw InferenceFailureException(
        _withLibraryPath(libraryFailure, library.path),
      );
    }

    final configuredPath = params.modelPath.trim();
    if (configuredPath.isEmpty) {
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.modelNotFound,
          'No model path configured.',
          null,
        ),
      );
    }
    final modelPath = p.normalize(p.absolute(configuredPath));
    if (!FileSystemEntity.isFileSync(modelPath)) {
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.modelNotFound,
          'model file not found: $modelPath',
          modelPath,
        ),
      );
    }

    final bindings = library.bindings;
    _release();

    final modelParams = bindings.llamaModelDefaultParams();
    modelParams.nGpuLayers = params.gpuLayers;

    final modelPathPointer = modelPath.toNativeUtf8().cast<ffi.Char>();
    final ffi.Pointer<LlamaModel> model;
    try {
      model = bindings.llamaModelLoadFromFile(modelPathPointer, modelParams);
    } finally {
      malloc.free(modelPathPointer);
    }
    if (model == ffi.nullptr) {
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.nativeError,
          'llama_model_load_from_file returned null for $modelPath; '
          'check the file and the --gpu-layers value',
          modelPath,
        ),
      );
    }

    final vocab = bindings.llamaModelGetVocab(model);
    if (vocab == ffi.nullptr) {
      bindings.llamaModelFree(model);
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.nativeError,
          'llama_model_get_vocab returned null for $modelPath',
          modelPath,
        ),
      );
    }

    final batchSize = math.min(_maxBatchSize, params.contextSize);
    final contextParams = bindings.llamaContextDefaultParams()
      ..nCtx = params.contextSize
      ..nBatch = batchSize
      ..nUbatch = batchSize
      ..nThreads = params.threads
      ..nThreadsBatch = params.threads
      ..nSeqMax = 1
      ..noPerf = false;

    final context = bindings.llamaInitFromModel(model, contextParams);
    if (context == ffi.nullptr) {
      bindings.llamaModelFree(model);
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.nativeError,
          'llama_init_from_model returned null for n_ctx '
          '${params.contextSize}',
          modelPath,
        ),
      );
    }

    _model = model;
    _context = context;
    _nCtx = bindings.llamaNCtx(context);
    _nBatch = bindings.llamaNBatch(context);
    bindings.llamaPerfContextReset(context);
  }

  @override
  void begin(GenerationRequest request) {
    final library = _library;
    final model = _model;
    final context = _context;
    final nCtx = _nCtx;
    final nBatch = _nBatch;
    if (library == null ||
        model == null ||
        context == null ||
        nCtx == null ||
        nBatch == null) {
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.engineUnavailable,
          'no model is loaded; call load() before begin()',
          null,
        ),
      );
    }
    if (nBatch <= 0) {
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.nativeError,
          'the loaded context reports n_batch $nBatch',
          null,
        ),
      );
    }

    final prompt = request.prompt;
    if (prompt.contains('\u0000')) {
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.invalidParams,
          'the prompt contains a NUL character',
          null,
        ),
      );
    }

    final bindings = library.bindings;
    _clearGeneration(freeSampler: true);
    _accumulator = Utf8TokenAccumulator();

    bindings.llamaMemoryClear(bindings.llamaGetMemory(context), true);
    bindings.llamaPerfContextReset(context);

    final vocab = bindings.llamaModelGetVocab(model);
    if (vocab == ffi.nullptr) {
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.nativeError,
          'llama_model_get_vocab returned null before tokenization',
          null,
        ),
      );
    }

    final tokenized = _tokenize(bindings, vocab, prompt);

    // Keep enough room for the requested output, never spilling past the
    // context. Left truncation keeps the newest part of a long prompt.
    final requestedMax = request.params.maxTokens;
    final keepLimit = math.max(1, math.min(nCtx - 1, nCtx - requestedMax));
    var tokens = tokenized;
    if (tokens.length > keepLimit) {
      tokens = Int32List.sublistView(tokens, tokens.length - keepLimit);
    }

    _buildSampler(bindings, request.params);

    _pending = tokens;
    _position = 0;
    _generated = 0;
    _maxTokens = math.max(0, math.min(requestedMax, nCtx - tokens.length));
    _promptTokenCount = tokens.length;
    _active = true;
    _cancelled = false;
    _finished = false;
    _stopwatch
      ..reset()
      ..start();
  }

  @override
  Future<GenerationStep?> next() async {
    if (_cancelled) {
      _clearGeneration(freeSampler: true);
      return null;
    }
    if (_finished || !_active) {
      return null;
    }

    final library = _library;
    final model = _model;
    final context = _context;
    final nBatch = _nBatch;
    if (library == null || model == null || context == null) {
      _clearGeneration(freeSampler: true);
      return null;
    }
    final bindings = library.bindings;
    if (nBatch == null || nBatch <= 0) {
      _stopGeneration();
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.nativeError,
          'the loaded context has no usable batch size',
          null,
        ),
      );
    }

    if (_position < _pending.length) {
      final chunk = math.min(nBatch, _pending.length - _position);
      final batch = bindings.llamaBatchInit(chunk, 0, 1);
      try {
        batch.nTokens = chunk;
        for (var i = 0; i < chunk; i++) {
          final position = _position + i;
          batch.token[i] = _pending[position];
          batch.pos[i] = position;
          batch.nSeqId[i] = 1;
          batch.seqId[i][0] = 0;
          batch.logits[i] = position == _pending.length - 1 ? 1 : 0;
        }
        final result = bindings.llamaDecode(context, batch);
        if (result != 0) {
          _stopGeneration();
          throw _decodeFailure(result);
        }
      } finally {
        bindings.llamaBatchFree(batch);
      }
      _position += chunk;
      if (_position < _pending.length) {
        return GenerationStep(metrics: _metrics(bindings, context));
      }
    }

    final sampler = _sampler;
    if (sampler == null) {
      _clearGeneration(freeSampler: true);
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.engineUnavailable,
          'no sampler is initialised; call begin() before next()',
          null,
        ),
      );
    }
    final vocab = bindings.llamaModelGetVocab(model);
    if (vocab == ffi.nullptr) {
      _stopGeneration();
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.nativeError,
          'llama_model_get_vocab returned null while sampling',
          null,
        ),
      );
    }

    // `llama_sampler_sample` accepts internally: the chain sees the sampled
    // token exactly once.
    final sampled = bindings.llamaSamplerSample(sampler, context, -1);
    if (bindings.llamaVocabIsEog(vocab, sampled)) {
      final text = _accumulator.flush();
      _finishGeneration();
      return GenerationStep(
        text: text,
        metrics: _metrics(bindings, context),
        done: true,
      );
    }

    // Feed the sampled token back in so the next sample sees its logits instead
    // of the prefill logits.
    final batch = bindings.llamaBatchInit(1, 0, 1);
    try {
      batch.nTokens = 1;
      batch.token[0] = sampled;
      batch.pos[0] = _position;
      batch.nSeqId[0] = 1;
      batch.seqId[0][0] = 0;
      batch.logits[0] = 1;
      final result = bindings.llamaDecode(context, batch);
      if (result != 0) {
        _stopGeneration();
        throw _decodeFailure(result);
      }
    } finally {
      bindings.llamaBatchFree(batch);
    }
    _position += 1;

    _accumulator.add(_tokenBytes(bindings, vocab, sampled));
    _generated += 1;
    final text = _accumulator.takeDecoded() ?? '';
    if (_generated >= _maxTokens) {
      final remainder = _accumulator.flush();
      _finishGeneration();
      return GenerationStep(
        text: '$text$remainder',
        metrics: _metrics(bindings, context),
        done: true,
      );
    }
    return GenerationStep(text: text, metrics: _metrics(bindings, context));
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
  }

  @override
  Future<void> unload() async {
    _release();
  }

  @override
  Future<void> dispose() async {
    // The llama backend is process-global: freeing it here would break any
    // other session. Only this session's model and context are released.
    _release();
  }

  Future<LlamaLibrary> _ensureLibrary() async {
    final cached = _library;
    if (cached != null) {
      return cached;
    }
    final opened = await LlamaLibrary.open(_libraryPath);
    return _library = opened;
  }

  /// Tokenizes [prompt] with the probe/allocate/retry dance llama.cpp needs.
  Int32List _tokenize(
    LlamaBindings bindings,
    ffi.Pointer<LlamaVocab> vocab,
    String prompt,
  ) {
    final promptBytes = utf8.encode(prompt);
    final text = calloc<ffi.Uint8>(math.max(1, promptBytes.length));
    try {
      if (promptBytes.isNotEmpty) {
        text.asTypedList(promptBytes.length).setAll(0, promptBytes);
      }
      final textPointer = text.cast<ffi.Char>();
      final probe = bindings.llamaTokenize(
        vocab,
        textPointer,
        promptBytes.length,
        ffi.nullptr,
        0,
        true,
        true,
      );
      if (probe == _int32Min) {
        throw InferenceFailureException(
          _failure(
            InferenceFailureCode.nativeError,
            'llama_tokenize overflowed int32',
            null,
          ),
        );
      }
      if (probe == 0) {
        throw InferenceFailureException(
          _failure(
            InferenceFailureCode.invalidParams,
            'the prompt tokenized to no tokens',
            null,
          ),
        );
      }
      final capacity = probe < 0 ? -probe : probe;
      final buffer = calloc<ffi.Int32>(capacity);
      try {
        final written = bindings.llamaTokenize(
          vocab,
          textPointer,
          promptBytes.length,
          buffer,
          capacity,
          true,
          true,
        );
        if (written < 0) {
          throw InferenceFailureException(
            _failure(
              InferenceFailureCode.nativeError,
              'llama_tokenize failed with code $written',
              'llama_tokenize returned $written',
            ),
          );
        }
        if (written == 0) {
          throw InferenceFailureException(
            _failure(
              InferenceFailureCode.invalidParams,
              'the prompt tokenized to no tokens',
              null,
            ),
          );
        }
        final count = math.min(written, capacity);
        return Int32List.fromList(
          buffer.asTypedList(count).toList(growable: false),
        );
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(text);
    }
  }

  /// Builds the top-k/top-p/min-p/temperature/dist chain for [params].
  void _buildSampler(LlamaBindings bindings, ModelParams params) {
    _freeSampler();
    final chainParams = calloc<LlamaSamplerChainParams>();
    try {
      chainParams.ref.noPerf = false;
      final chain = bindings.llamaSamplerChainInit(chainParams.ref);
      if (chain == ffi.nullptr) {
        throw InferenceFailureException(
          _failure(
            InferenceFailureCode.nativeError,
            'llama_sampler_chain_init returned null',
            null,
          ),
        );
      }
      bindings.llamaSamplerChainAdd(
        chain,
        bindings.llamaSamplerInitTopK(params.topK),
      );
      bindings.llamaSamplerChainAdd(
        chain,
        bindings.llamaSamplerInitTopP(params.topP, 1),
      );
      bindings.llamaSamplerChainAdd(
        chain,
        bindings.llamaSamplerInitMinP(0.05, 1),
      );
      bindings.llamaSamplerChainAdd(
        chain,
        bindings.llamaSamplerInitTemp(params.temperature),
      );
      bindings.llamaSamplerChainAdd(
        chain,
        bindings.llamaSamplerInitDist(_defaultSeed),
      );
      _sampler = chain;
    } finally {
      calloc.free(chainParams);
    }
  }

  /// Returns the exact UTF-8 bytes of [token], growing the buffer when the
  /// first `llama_token_to_piece` call reports the required size.
  List<int> _tokenBytes(
    LlamaBindings bindings,
    ffi.Pointer<LlamaVocab> vocab,
    int token,
  ) {
    var capacity = _pieceBufferSize;
    var buffer = calloc<ffi.Char>(capacity);
    try {
      final written = bindings.llamaTokenToPiece(
        vocab,
        token,
        buffer,
        capacity,
        0,
        false,
      );
      if (written >= 0) {
        return _bytesOf(buffer, written);
      }
      final required = -written;
      if (required <= 0) {
        throw InferenceFailureException(
          _failure(
            InferenceFailureCode.nativeError,
            'llama_token_to_piece returned $written',
            null,
          ),
        );
      }
      calloc.free(buffer);
      capacity = required;
      buffer = calloc<ffi.Char>(capacity);
      final retry = bindings.llamaTokenToPiece(
        vocab,
        token,
        buffer,
        capacity,
        0,
        false,
      );
      if (retry < 0) {
        throw InferenceFailureException(
          _failure(
            InferenceFailureCode.nativeError,
            'llama_token_to_piece failed with code $retry',
            'llama_token_to_piece returned $retry',
          ),
        );
      }
      return _bytesOf(buffer, retry);
    } finally {
      calloc.free(buffer);
    }
  }

  static List<int> _bytesOf(ffi.Pointer<ffi.Char> buffer, int length) {
    if (length <= 0) {
      return const <int>[];
    }
    return buffer.cast<ffi.Uint8>().asTypedList(length).toList(growable: false);
  }

  /// Snapshots the cumulative counters.
  ///
  /// llama.cpp reports `n_eval` as the tokens evaluated during generation,
  /// which is one per emitted token because each sampled token is decoded
  /// before the next sample. The counts here come from `_generated`, so they
  /// stay authoritative even when the native counter lags. Timings fall back
  /// to the request stopwatch when the library reports zero for a phase.
  GenerationMetrics _metrics(
    LlamaBindings bindings,
    ffi.Pointer<LlamaContext> context,
  ) {
    final perf = bindings.llamaPerfContext(context);
    final elapsed = _stopwatch.elapsedMilliseconds;
    var promptEvalMs = perf.tPEvalMs.round();
    var evalMs = perf.tEvalMs.round();
    if (promptEvalMs <= 0) {
      promptEvalMs = elapsed;
    }
    if (evalMs <= 0) {
      evalMs = elapsed;
    }
    return GenerationMetrics(
      (b) => b
        ..promptTokenCount = _promptTokenCount
        ..generatedTokenCount = _generated
        ..promptEvalMs = promptEvalMs
        ..evalMs = evalMs,
    );
  }

  InferenceFailureException _decodeFailure(int code) {
    final hint = code == -1
        ? " (couldn't find a KV slot; reduce --context-size or --parallel)"
        : '';
    return InferenceFailureException(
      _failure(
        InferenceFailureCode.nativeError,
        'llama_decode failed with code $code$hint',
        'llama_decode returned $code',
      ),
    );
  }

  void _finishGeneration() {
    _active = false;
    _finished = true;
    _stopwatch.stop();
  }

  void _stopGeneration() {
    _freeSampler();
    _pending = Int32List(0);
    _active = false;
    _finished = true;
    _stopwatch.stop();
  }

  void _clearGeneration({bool freeSampler = false}) {
    if (freeSampler) {
      _freeSampler();
    }
    _pending = Int32List(0);
    _position = 0;
    _generated = 0;
    _maxTokens = 0;
    _promptTokenCount = 0;
    _active = false;
    _cancelled = false;
    _finished = false;
    _stopwatch.stop();
    _accumulator = Utf8TokenAccumulator();
  }

  void _freeSampler() {
    final library = _library;
    final sampler = _sampler;
    if (library != null && sampler != null) {
      library.bindings.llamaSamplerFree(sampler);
    }
    _sampler = null;
  }

  /// Frees sampler, context (and with it the KV memory) and model, in that
  /// order. Safe to call repeatedly: every pointer is nulled first.
  void _release() {
    final library = _library;
    _clearGeneration(freeSampler: true);

    final context = _context;
    if (library != null && context != null) {
      library.bindings.llamaFree(context);
    }
    _context = null;

    final model = _model;
    if (library != null && model != null) {
      library.bindings.llamaModelFree(model);
    }
    _model = null;

    _nCtx = null;
    _nBatch = null;
  }

  static InferenceFailure _withLibraryPath(
    InferenceFailure failure,
    String path,
  ) => failure.rebuild(
    (b) => b..message = '${failure.message} [library: $path]',
  );

  static InferenceFailure _failure(
    InferenceFailureCode code,
    String message,
    String? details,
  ) => InferenceFailure(
    (b) => b
      ..code = code
      ..message = message
      ..details = details,
  );
}
