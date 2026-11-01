import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

/// `void ggml_backend_load_all_from_path(const char * dir_path)`.
typedef GgmlBackendLoadAllFromPathC = ffi.Void Function(ffi.Pointer<Utf8>);

/// Dart signature of `ggml_backend_load_all_from_path`.
typedef GgmlBackendLoadAllFromPath = void Function(ffi.Pointer<Utf8>);

/// The one symbol this app needs from `libggml`.
///
/// The function scans a directory for backend plugins (`libggml-cuda.so`,
/// `libggml-vulkan.so`, …) and registers them with the scheduler. Without it a
/// library directory that carries a GPU backend silently runs on the CPU,
/// which is the failure this binding exists to prevent.
final class GgmlBackendBindings {
  const GgmlBackendBindings._(this._loadAllFromPath);

  final GgmlBackendLoadAllFromPath _loadAllFromPath;

  /// Binds [library], or returns null when it is not the loader library.
  ///
  /// The symbol lives in the top-level `libggml`, not in every `libggml-*`
  /// plugin, so the caller tries each preloaded sibling and keeps the first
  /// that answers.
  static GgmlBackendBindings? tryBind(ffi.DynamicLibrary library) {
    try {
      return GgmlBackendBindings._(
        library.lookupFunction<
          GgmlBackendLoadAllFromPathC,
          GgmlBackendLoadAllFromPath
        >('ggml_backend_load_all_from_path'),
      );
    } on ArgumentError {
      return null;
    }
  }

  /// Registers every backend plugin in [directory].
  void loadAllFromPath(String directory) {
    final pointer = directory.toNativeUtf8();
    try {
      _loadAllFromPath(pointer);
    } finally {
      calloc.free(pointer);
    }
  }
}
