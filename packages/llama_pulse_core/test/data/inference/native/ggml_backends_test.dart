import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:llama_pulse_core/src/data/inference/llama_version_pin.dart';
import 'package:llama_pulse_core/src/data/inference/native/llama_library.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../support/native/fake_llama_builder.dart';

/// Reads the fake `libggml` control surface beside the main library.
final class _FakeGgml {
  _FakeGgml(String directory)
    : _library = ffi.DynamicLibrary.open(
        p.join(directory, switch (Platform.operatingSystem) {
          'macos' => 'libggml_fake.dylib',
          'windows' => 'ggml_fake.dll',
          _ => 'libggml_fake.so',
        }),
      );

  final ffi.DynamicLibrary _library;

  late final int Function() loadCalls = _library
      .lookupFunction<ffi.Int32 Function(), int Function()>(
        'fake_ggml_load_calls',
      );

  late final int Function() initCountAtLoad = _library
      .lookupFunction<ffi.Int32 Function(), int Function()>(
        'fake_ggml_init_count_at_load',
      );

  late final ffi.Pointer<Utf8> Function() lastPath = _library
      .lookupFunction<
        ffi.Pointer<Utf8> Function(),
        ffi.Pointer<Utf8> Function()
      >('fake_ggml_last_path');
}

void main() {
  late Directory temp;
  String? skipReason;

  setUpAll(() async {
    if (!await FakeLlamaBuilder.isAvailable) {
      skipReason = 'clang is not installed; the native shim needs a compiler';
    }
  });

  setUp(() {
    temp = Directory.systemTemp.createTempSync('llama_pulse_ggml_');
  });

  tearDown(() {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('registers backends before llama_backend_init', () async {
    if (skipReason != null) {
      return;
    }
    final libraryPath = await FakeLlamaBuilder.buildBundle(temp);
    final ggml = _FakeGgml(temp.path);

    final library = await LlamaLibrary.open(libraryPath);

    expect(library.isUsable, isTrue, reason: '${library.failure}');
    expect(library.version, LlamaVersionPin.version);
    expect(ggml.loadCalls(), 1);
    expect(ggml.lastPath().toDartString(), p.dirname(libraryPath));
    // The fake llama shim reports how many backend inits had run when the
    // loader was called: zero means the registration happened first.
    expect(ggml.initCountAtLoad(), 0);
  });

  test('a directory without libggml still opens', () async {
    if (skipReason != null) {
      return;
    }
    final shim = await FakeLlamaBuilder.build();
    final libraryPath = await File(shim)
        .copy(p.join(temp.path, p.basename(shim)));

    final library = await LlamaLibrary.open(libraryPath.path);

    expect(library.isUsable, isTrue, reason: '${library.failure}');
  });
}
