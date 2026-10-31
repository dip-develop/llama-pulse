import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../../../domain/entities/generation_request.dart';
import '../../../domain/entities/inference_failure.dart';
import '../../../domain/entities/inference_failure_code.dart';
import '../../../domain/entities/model_params.dart';
import '../../../domain/exceptions/inference_failure_exception.dart';
import '../../../domain/gateways/llama_session.dart';
import 'llama_bindings.dart';
import 'llama_library.dart';

/// The real [LlamaSession], backed by a llama.cpp shared library.
///
/// The library is opened lazily on the first [load], and a failed open is
/// recorded rather than thrown so [load] can report a structured
/// [InferenceFailureException] that includes the resolved library path.
///
/// Generation is not wired up yet: [begin] and [next] throw
/// [UnimplementedError], while [cancel] is an always-safe no-op.
final class NativeLlamaSession implements LlamaSession {
  /// Creates a session that will load [libraryPath] on first use.
  // A public name is required here, so an initializing formal would expose the
  // private field as `_libraryPath` and callers could not pass it.
  NativeLlamaSession({required String libraryPath})
    // ignore: prefer_initializing_formals
    : _libraryPath = libraryPath;

  /// The largest batch llama.cpp is given for this app's models.
  static const int _maxBatchSize = 512;

  String _libraryPath;
  LlamaLibrary? _library;

  ffi.Pointer<LlamaModel>? _model;
  ffi.Pointer<LlamaContext>? _context;
  ffi.Pointer<LlamaSampler>? _sampler;

  int? _nCtx;
  int? _nBatch;

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
    throw UnimplementedError('native generation is not implemented yet');
  }

  @override
  Future<GenerationStep?> next() async {
    throw UnimplementedError('native generation is not implemented yet');
  }

  @override
  Future<void> cancel() async {
    // Nothing is running yet; cancelling must stay safe for the worker.
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

  /// Frees sampler, context (and with it the KV memory) and model, in that
  /// order. Safe to call repeatedly: every pointer is nulled first.
  void _release() {
    final library = _library;
    final sampler = _sampler;
    if (library != null && sampler != null) {
      library.bindings.llamaSamplerFree(sampler);
    }
    _sampler = null;

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
