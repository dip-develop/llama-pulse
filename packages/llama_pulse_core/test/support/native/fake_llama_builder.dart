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
