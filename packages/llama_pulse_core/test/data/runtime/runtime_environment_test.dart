import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  group('RuntimeEnvironment', () {
    test('prefixes every loader path and pins the backend directory', () {
      final overrides = RuntimeEnvironment.forDirectory(
        '/home/u/.config/llama_pulse/runtime/v0.8.0/cuda13',
        base: const <String, String>{
          'PATH': '/usr/bin',
          'LD_LIBRARY_PATH': '/opt/lib',
        },
        operatingSystem: 'linux',
      );

      expect(
        overrides['LD_LIBRARY_PATH'],
        '/home/u/.config/llama_pulse/runtime/v0.8.0/cuda13:/opt/lib',
      );
      expect(
        overrides['DYLD_LIBRARY_PATH'],
        '/home/u/.config/llama_pulse/runtime/v0.8.0/cuda13',
      );
      expect(
        overrides['PATH'],
        '/home/u/.config/llama_pulse/runtime/v0.8.0/cuda13:/usr/bin',
      );
      expect(
        overrides['GGML_BACKEND_PATH'],
        '/home/u/.config/llama_pulse/runtime/v0.8.0/cuda13',
      );
    });

    test('uses semicolons on Windows', () {
      final overrides = RuntimeEnvironment.forDirectory(
        r'C:\runtime\v0.8.0\cpu',
        base: const <String, String>{'PATH': r'C:\Windows'},
        operatingSystem: 'windows',
      );

      expect(overrides['PATH'], r'C:\runtime\v0.8.0\cpu;C:\Windows');
      expect(overrides['LD_LIBRARY_PATH'], r'C:\runtime\v0.8.0\cpu');
    });

    test('a blank inherited value leaves only the runtime directory', () {
      final overrides = RuntimeEnvironment.forDirectory(
        '/runtime',
        base: const <String, String>{'LD_LIBRARY_PATH': '  '},
      );

      expect(overrides['LD_LIBRARY_PATH'], '/runtime');
      expect(overrides.length, 4);
    });
  });
}
