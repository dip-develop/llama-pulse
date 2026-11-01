import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../../../domain/entities/inference_failure.dart';
import '../../../domain/entities/inference_failure_code.dart';
import '../../runtime/runtime_attestation.dart';
import '../llama_version_pin.dart';
import 'ggml_backend_bindings.dart';
import 'llama_bindings.dart';

/// A loaded llama.cpp shared library, or the reason it could not be loaded.
///
/// [open] never throws: every loader, lookup, version and initialisation
/// problem is reported through [failure], which lets the worker keep the
/// session alive and surface a structured error instead of crashing.
///
/// There is deliberately no `dlclose`: `dart:ffi` does not expose one, so a
/// library stays mapped for the lifetime of the process once opened. Opening
/// the same path again is cheap because the loader returns the same handle.
final class LlamaLibrary {
  LlamaLibrary._({
    required this.bindings,
    required this.path,
    required this.version,
    required this.failure,
  });

  /// Whether `llama_backend_init` already ran in this process.
  ///
  /// The backend is process-global: initialising it twice is a bug in
  /// llama.cpp, so it is guarded here rather than at every call site.
  static bool _backendInitialised = false;

  /// The bound C functions for this library.
  final LlamaBindings bindings;

  /// The absolute path passed to `DynamicLibrary.open`.
  final String path;

  /// The string `llama_version()` reported, or `''` when it never ran.
  final String version;

  /// Why the library is unusable, or null when it is ready.
  final InferenceFailure? failure;

  /// Whether [bindings] can be called.
  bool get isUsable => failure == null;

  /// Opens the shared library at [path] and validates the pin.
  ///
  /// Never throws. A relative, empty or missing path, a loader failure, a
  /// missing symbol or a version mismatch all produce a [failure] instead.
  static Future<LlamaLibrary> open(String path) async {
    final bindings = LlamaBindings();

    if (path.trim().isEmpty) {
      return LlamaLibrary._(
        bindings: bindings,
        path: path,
        version: '',
        failure: _failure(
          InferenceFailureCode.libraryNotFound,
          'library path is empty',
          path,
        ),
      );
    }
    if (!p.isAbsolute(path)) {
      return LlamaLibrary._(
        bindings: bindings,
        path: path,
        version: '',
        failure: _failure(
          InferenceFailureCode.libraryNotFound,
          'library path must be absolute',
          path,
        ),
      );
    }

    // Best effort: a sibling that cannot be listed or opened must not stop the
    // main library from being bound, because `open` never throws.
    ffi.DynamicLibrary? ggml;
    try {
      ggml = _preloadSiblings(path);
    } on FileSystemException {
      // The main library may be self-contained or find its dependencies itself.
    } on UnsupportedError {
      // Some platforms/filesystems do not support directory listing here.
    }

    final ffi.DynamicLibrary library;
    try {
      library = ffi.DynamicLibrary.open(path);
    } on Object catch (error) {
      return LlamaLibrary._(
        bindings: bindings,
        path: path,
        version: '',
        failure: _failure(
          InferenceFailureCode.libraryNotFound,
          'could not open $path',
          '$error',
        ),
      );
    }

    try {
      bindings.lookupAll(library);
    } on ArgumentError catch (error) {
      final symbol = _missingSymbol(error);
      return LlamaLibrary._(
        bindings: bindings,
        path: path,
        version: '',
        failure: _failure(
          InferenceFailureCode.nativeError,
          symbol == null ? 'symbol missing in $path' : 'symbol $symbol missing',
          '$error',
        ),
      );
    }

    final versionPointer = bindings.llamaVersion();
    if (versionPointer == ffi.nullptr) {
      return LlamaLibrary._(
        bindings: bindings,
        path: path,
        version: '',
        failure: _failure(
          InferenceFailureCode.nativeError,
          'llama_version() returned null',
          path,
        ),
      );
    }
    final version = versionPointer.toDartString();

    if (!LlamaVersionPin.matches(version)) {
      final attestation = LlamaVersionPin.isDev(version)
          ? RuntimeAttestation.read(path)
          : null;
      if (attestation == null || !attestation.isAttested) {
        final details = StringBuffer('llama_version() reported "$version"');
        if (attestation != null) {
          details.write('; ${attestation.reason}');
        }
        return LlamaLibrary._(
          bindings: bindings,
          path: path,
          version: version,
          failure: LlamaVersionPin.mismatch(version)
              .rebuild((b) => b..details = details.toString()),
        );
      }
    }

    if (!_backendInitialised) {
      // Backends must be registered before the backend registry is
      // initialised; doing it afterwards leaves the process on the CPU.
      final loader = ggml == null ? null : GgmlBackendBindings.tryBind(ggml);
      loader?.loadAllFromPath(p.dirname(path));
      bindings.llamaBackendInit();
      _backendInitialised = true;
    }

    return LlamaLibrary._(
      bindings: bindings,
      path: path,
      version: version,
      failure: null,
    );
  }

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

  /// Pre-opens `libggml*` siblings so `libllama` resolves them.
  ///
  /// Some builds rely on an rpath and some do not; opening the siblings first
  /// is harmless and makes a plain directory drop-in work. Returns the handle
  /// that exports `ggml_backend_load_all_from_path`, or null when the directory
  /// has no such library.
  static ffi.DynamicLibrary? _preloadSiblings(String libraryPath) {
    final directory = File(libraryPath).parent;
    if (!directory.existsSync()) {
      return null;
    }
    final pattern = switch (Platform.operatingSystem) {
      'macos' => RegExp(r'^libggml.*\.dylib$'),
      'windows' => RegExp(r'^ggml.*\.dll$', caseSensitive: false),
      _ => RegExp(r'^libggml.*\.so(\.[0-9.]+)?$'),
    };
    final siblings =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => pattern.hasMatch(p.basename(file.path)))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    ffi.DynamicLibrary? backendLoader;
    for (final sibling in siblings) {
      if (p.equals(sibling.path, libraryPath)) {
        continue;
      }
      try {
        final handle = ffi.DynamicLibrary.open(sibling.path);
        if (backendLoader == null &&
            GgmlBackendBindings.tryBind(handle) != null) {
          backendLoader = handle;
        }
      } on ArgumentError {
        // Best effort: the main library may be self-contained or find its
        // dependency through its own rpath.
      }
    }
    return backendLoader;
  }

  static String? _missingSymbol(ArgumentError error) {
    final match = RegExp(r"""symbol ['"]?([A-Za-z_][A-Za-z0-9_]*)""")
        .firstMatch('$error');
    return match?.group(1);
  }
}
