import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

/// Compiles `test/support/native/fake_llama.c` once per test process.
///
/// The resulting shared library exports the llama.cpp surface the bindings
/// look up, plus the `fake_llama_*` control/getter functions. Nothing here
/// touches a real llama.cpp build.
final class FakeLlamaBuilder {
  FakeLlamaBuilder._();

  static String? _cachedLibraryPath;
  static bool? _available;

  /// Whether `clang` can be executed on this machine.
  static Future<bool> get isAvailable async {
    final cached = _available;
    if (cached != null) {
      return cached;
    }
    try {
      final result = await Process.run('clang', const ['--version']);
      return _available = result.exitCode == 0;
    } on ProcessException {
      return _available = false;
    }
  }

  /// Builds the shim (once) and returns the path to the shared library.
  static Future<String> build() async {
    final cached = _cachedLibraryPath;
    if (cached != null) {
      return cached;
    }

    final repoRoot = _findRepoRoot();
    final source = p.join(
      repoRoot.path,
      'packages',
      'llama_pulse_core',
      'test',
      'support',
      'native',
      'fake_llama.c',
    );
    final include = p.join(
      repoRoot.path,
      'third_party',
      'llama_cpp',
      'v0.8.0',
      'include',
    );
    final directory = Directory.systemTemp.createTempSync(
      'llama_pulse_fake_llama_',
    );
    final output = p.join(directory.path, _libraryFileName);

    final result = await Process.run('clang', [
      '-shared',
      '-fPIC',
      '-std=c11',
      '-I',
      include,
      source,
      '-o',
      output,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'clang could not build fake_llama.c '
        '(exit ${result.exitCode}):\n${result.stderr}',
      );
    }
    return _cachedLibraryPath = output;
  }

  static String get _libraryFileName => switch (Platform.operatingSystem) {
    'macos' => 'libfake_llama.dylib',
    'windows' => 'fake_llama.dll',
    _ => 'libfake_llama.so',
  };
}

/// Typed access to the shim's recorder and test controls.
final class FakeLlama {
  /// Opens the already-built shim at [path].
  FakeLlama(String path) : _library = ffi.DynamicLibrary.open(path);

  final ffi.DynamicLibrary _library;

  late final void Function(ffi.Pointer<Utf8>) _setVersion = _library
      .lookupFunction<
        ffi.Void Function(ffi.Pointer<Utf8>),
        void Function(ffi.Pointer<Utf8>)
      >('fake_llama_set_version');

  late final void Function(int) _setFailModel = _library
      .lookupFunction<ffi.Void Function(ffi.Int32), void Function(int)>(
        'fake_llama_set_fail_model',
      );

  late final void Function(int) _setFailContext = _library
      .lookupFunction<ffi.Void Function(ffi.Int32), void Function(int)>(
        'fake_llama_set_fail_ctx',
      );

  late final void Function() _reset = _library
      .lookupFunction<ffi.Void Function(), void Function()>('fake_llama_reset');

  late final void Function(int) _setTokenizeResult = _library
      .lookupFunction<ffi.Void Function(ffi.Int32), void Function(int)>(
        'fake_llama_set_tokenize_result',
      );

  late final void Function(ffi.Pointer<ffi.Int32>, int) _setTokens = _library
      .lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Int32>, ffi.Int32),
        void Function(ffi.Pointer<ffi.Int32>, int)
      >('fake_llama_set_tokens');

  late final void Function(ffi.Pointer<ffi.Pointer<Utf8>>, int) _setPieces =
      _library.lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Pointer<Utf8>>, ffi.Int32),
        void Function(ffi.Pointer<ffi.Pointer<Utf8>>, int)
      >('fake_llama_set_pieces');

  late final void Function(int, ffi.Pointer<ffi.Uint8>, int) _setPieceBytes =
      _library.lookupFunction<
        ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Uint8>, ffi.Int32),
        void Function(int, ffi.Pointer<ffi.Uint8>, int)
      >('fake_llama_set_piece_bytes');

  late final void Function(int) _setPieceBytesLong = _library
      .lookupFunction<ffi.Void Function(ffi.Int32), void Function(int)>(
        'fake_llama_set_piece_bytes_long',
      );

  late final void Function(int) _setDecodeResult = _library
      .lookupFunction<ffi.Void Function(ffi.Int32), void Function(int)>(
        'fake_llama_set_decode_result',
      );

  late final void Function(int) _setSampleIndex = _library
      .lookupFunction<ffi.Void Function(ffi.Int32), void Function(int)>(
        'fake_llama_set_sample_index',
      );

  late final void Function(double, double, int, int) _setPerf = _library
      .lookupFunction<
        ffi.Void Function(ffi.Double, ffi.Double, ffi.Int32, ffi.Int32),
        void Function(double, double, int, int)
      >('fake_llama_set_perf');

  late final int Function() _gpuLayers = _intGetter('fake_llama_gpu_layers');

  late final int Function() _ctxSize = _intGetter('fake_llama_ctx_size');

  late final int Function() _batchSize = _intGetter('fake_llama_batch_size');

  late final int Function() _ubatchSize = _intGetter('fake_llama_ubatch_size');

  late final int Function() _threads = _intGetter('fake_llama_threads');

  late final int Function() _threadsBatch = _intGetter(
    'fake_llama_threads_batch',
  );

  late final int Function() _seqMax = _intGetter('fake_llama_seq_max');

  late final int Function() _noPerf = _intGetter('fake_llama_no_perf');

  late final int Function() _modelFreeCount = _intGetter(
    'fake_llama_model_free_count',
  );

  late final int Function() _ctxFreeCount = _intGetter(
    'fake_llama_ctx_free_count',
  );

  late final int Function() _backendInitCount = _intGetter(
    'fake_llama_backend_init_count',
  );

  late final int Function() _tokenizeCalls = _intGetter(
    'fake_llama_tokenize_calls',
  );

  late final int Function() _tokenizeAddSpecial = _intGetter(
    'fake_llama_tokenize_add_special',
  );

  late final int Function() _tokenizeParseSpecial = _intGetter(
    'fake_llama_tokenize_parse_special',
  );

  late final int Function() _tokenizeTextLen = _intGetter(
    'fake_llama_tokenize_text_len',
  );

  late final ffi.Pointer<Utf8> Function() _tokenizeText = _library
      .lookupFunction<
        ffi.Pointer<Utf8> Function(),
        ffi.Pointer<Utf8> Function()
      >('fake_llama_tokenize_text');

  late final int Function() _contractViolationCount = _intGetter(
    'fake_llama_contract_violation_count',
  );

  late final ffi.Pointer<Utf8> Function() _lastCallSequence = _library
      .lookupFunction<
        ffi.Pointer<Utf8> Function(),
        ffi.Pointer<Utf8> Function()
      >('fake_llama_last_call_sequence');

  late final int Function() _decodeCalls = _intGetter(
    'fake_llama_decode_calls',
  );

  late final int Function() _batchNodes = _intGetter('fake_llama_batch_nodes');

  late final int Function() _maxBatchTokens = _intGetter(
    'fake_llama_max_batch_tokens',
  );

  late final int Function() _totalBatchTokens = _intGetter(
    'fake_llama_total_batch_tokens',
  );

  late final int Function() _firstBatchPos = _intGetter(
    'fake_llama_first_batch_pos',
  );

  late final int Function() _lastBatchPos = _intGetter(
    'fake_llama_last_batch_pos',
  );

  late final int Function(int) _decodeLastPos = _library
      .lookupFunction<ffi.Int32 Function(ffi.Int32), int Function(int)>(
        'fake_llama_decode_last_pos',
      );

  late final int Function() _logitsCount = _intGetter(
    'fake_llama_logits_count',
  );

  late final int Function() _logitsLastOnly = _intGetter(
    'fake_llama_logits_last_only',
  );

  late final int Function() _batchFreeCount = _intGetter(
    'fake_llama_batch_free_count',
  );

  late final int Function() _memoryClearCount = _intGetter(
    'fake_llama_memory_clear_count',
  );

  late final int Function() _samplerInitCount = _intGetter(
    'fake_llama_sampler_init_count',
  );

  late final int Function() _samplerFreeCount = _intGetter(
    'fake_llama_sampler_free_count',
  );

  late final int Function() _sampleCalls = _intGetter(
    'fake_llama_sample_calls',
  );

  late final int Function() _perfResetCount = _intGetter(
    'fake_llama_perf_reset_count',
  );

  late final ffi.Pointer<Utf8> Function() _modelPath = _library
      .lookupFunction<
        ffi.Pointer<Utf8> Function(),
        ffi.Pointer<Utf8> Function()
      >('fake_llama_model_path');

  /// Overrides `llama_version()`; the shim copies [version].
  void setVersion(String version) {
    final pointer = version.toNativeUtf8();
    try {
      _setVersion(pointer);
    } finally {
      malloc.free(pointer);
    }
  }

  /// Restores the `FAKE_LLAMA_VERSION` fallback (or `0.8.0`).
  void clearVersion() => _setVersion(ffi.nullptr);

  /// Makes `llama_model_load_from_file` return null.
  void setFailModel(bool fail) => _setFailModel(fail ? 1 : 0);

  /// Makes `llama_init_from_model` return null.
  void setFailContext(bool fail) => _setFailContext(fail ? 1 : 0);

  /// Sets how many tokens `llama_tokenize` reports.
  ///
  /// A negative [count] makes the first probe return [count] and the next call
  /// fill a buffer of `-count` tokens.
  void setTokenizeResult(int count) => _setTokenizeResult(count);

  /// Sets the token ids the sampler returns, in order.
  void setTokens(List<int> ids) {
    final pointer = calloc<ffi.Int32>(ids.isEmpty ? 1 : ids.length);
    try {
      pointer.asTypedList(ids.length).setAll(0, ids);
      _setTokens(pointer, ids.length);
    } finally {
      calloc.free(pointer);
    }
  }

  /// Sets text pieces aligned with the scripted token ids.
  void setPieces(List<String> pieces) {
    final pointers = calloc<ffi.Pointer<Utf8>>(
      pieces.isEmpty ? 1 : pieces.length,
    );
    final strings = <ffi.Pointer<Utf8>>[];
    try {
      for (var i = 0; i < pieces.length; i++) {
        final string = pieces[i].toNativeUtf8();
        strings.add(string);
        pointers[i] = string;
      }
      _setPieces(pointers, pieces.length);
    } finally {
      for (final string in strings) {
        malloc.free(string);
      }
      calloc.free(pointers);
    }
  }

  /// Sets the raw bytes `llama_token_to_piece` returns for [token].
  void setPieceBytes(int token, List<int> bytes) {
    final pointer = calloc<ffi.Uint8>(bytes.isEmpty ? 1 : bytes.length);
    try {
      pointer.asTypedList(bytes.length).setAll(0, bytes);
      _setPieceBytes(token, pointer, bytes.length);
    } finally {
      calloc.free(pointer);
    }
  }

  /// Gives [token] a 256-byte piece, longer than the session's 64-byte buffer.
  void setPieceBytesLong(int token) => _setPieceBytesLong(token);

  /// Sets the value `llama_decode` returns.
  void setDecodeResult(int code) => _setDecodeResult(code);

  /// Sets the index into the scripted token list the next sample reads.
  void setSampleIndex(int index) => _setSampleIndex(index);

  /// Sets the data `llama_perf_context` reports.
  void setPerf({
    required double promptEvalMs,
    required double evalMs,
    required int promptTokens,
    required int generatedTokens,
  }) => _setPerf(promptEvalMs, evalMs, promptTokens, generatedTokens);

  /// Clears every recorded value and failure switch.
  void reset() => _reset();

  int get gpuLayers => _gpuLayers();

  String get modelPath {
    final pointer = _modelPath();
    return pointer == ffi.nullptr ? '' : pointer.toDartString();
  }

  int get ctxSize => _ctxSize();

  int get batchSize => _batchSize();

  int get ubatchSize => _ubatchSize();

  int get threads => _threads();

  int get threadsBatch => _threadsBatch();

  int get seqMax => _seqMax();

  bool get noPerf => _noPerf() != 0;

  int get modelFreeCount => _modelFreeCount();

  int get ctxFreeCount => _ctxFreeCount();

  int get backendInitCount => _backendInitCount();

  int get tokenizeCalls => _tokenizeCalls();

  bool get tokenizeAddSpecial => _tokenizeAddSpecial() != 0;

  bool get tokenizeParseSpecial => _tokenizeParseSpecial() != 0;

  String get tokenizeText {
    final pointer = _tokenizeText();
    return pointer == ffi.nullptr ? '' : pointer.toDartString();
  }

  int get tokenizeTextLen => _tokenizeTextLen();

  int get contractViolationCount => _contractViolationCount();

  /// The most recent sampler (`S`) and decode (`D`) calls, oldest first.
  String get lastCallSequence {
    final pointer = _lastCallSequence();
    return pointer == ffi.nullptr ? '' : pointer.toDartString();
  }

  int get decodeCalls => _decodeCalls();

  int get batchNodes => _batchNodes();

  int get maxBatchTokens => _maxBatchTokens();

  int get totalBatchTokens => _totalBatchTokens();

  int get firstBatchPos => _firstBatchPos();

  int get lastBatchPos => _lastBatchPos();

  /// The position of the last token in decode call [index], or -1 when no
  /// such decode happened.
  int decodeLastPos(int index) => _decodeLastPos(index);

  int get logitsCount => _logitsCount();

  bool get logitsLastOnly => _logitsLastOnly() != 0;

  int get batchFreeCount => _batchFreeCount();

  int get memoryClearCount => _memoryClearCount();

  int get samplerInitCount => _samplerInitCount();

  int get samplerFreeCount => _samplerFreeCount();

  int get sampleCalls => _sampleCalls();

  int get perfResetCount => _perfResetCount();

  int Function() _intGetter(String symbol) =>
      _library.lookupFunction<ffi.Int32 Function(), int Function()>(symbol);
}

Directory _findRepoRoot() {
  var directory = Directory.current.absolute;
  while (true) {
    if (File(
      p.join(
        directory.path,
        'third_party',
        'llama_cpp',
        'v0.8.0',
        'include',
        'llama.h',
      ),
    ).existsSync()) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'third_party/llama_cpp/v0.8.0/include/llama.h not found above '
        '${Directory.current.path}',
      );
    }
    directory = parent;
  }
}
