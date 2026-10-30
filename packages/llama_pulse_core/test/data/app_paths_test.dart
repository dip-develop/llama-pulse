import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AppPaths.resolve', () {
    test('LLAMA_PULSE_CONFIG_DIR wins when absolute', () {
      final paths = AppPaths.resolve(
        environment: {
          'LLAMA_PULSE_CONFIG_DIR': '/custom/config',
          'XDG_CONFIG_HOME': '/xdg',
          'HOME': '/home/user',
        },
        operatingSystem: 'linux',
      );

      expect(paths.configDirectory, '/custom/config');
    });

    test('a relative LLAMA_PULSE_CONFIG_DIR is ignored', () {
      final paths = AppPaths.resolve(
        environment: {
          'LLAMA_PULSE_CONFIG_DIR': 'relative/config',
          'HOME': '/home/user',
        },
        operatingSystem: 'linux',
      );

      expect(
        paths.configDirectory,
        p.join('/home/user', '.config', 'llamapulse'),
      );
    });

    test('uses an absolute XDG_CONFIG_HOME on Linux', () {
      final paths = AppPaths.resolve(
        environment: {'XDG_CONFIG_HOME': '/xdg', 'HOME': '/home/user'},
        operatingSystem: 'linux',
      );

      expect(paths.configDirectory, p.join('/xdg', 'llamapulse'));
    });

    test('falls back to HOME/.config on Linux', () {
      final paths = AppPaths.resolve(
        environment: {'HOME': '/home/user'},
        operatingSystem: 'linux',
      );

      expect(
        paths.configDirectory,
        p.join('/home/user', '.config', 'llamapulse'),
      );
    });

    test('uses the macOS Application Support directory', () {
      final paths = AppPaths.resolve(
        environment: {'HOME': '/Users/user'},
        operatingSystem: 'macos',
      );

      expect(
        paths.configDirectory,
        p.join('/Users/user', 'Library', 'Application Support', 'LlamaPulse'),
      );
    });

    test('uses APPDATA on Windows', () {
      final paths = AppPaths.resolve(
        environment: {'APPDATA': r'C:\Users\user\AppData\Roaming'},
        operatingSystem: 'windows',
      );

      expect(
        paths.configDirectory,
        p.join(r'C:\Users\user\AppData\Roaming', 'LlamaPulse'),
      );
    });

    test('falls back to USERPROFILE on Windows', () {
      final paths = AppPaths.resolve(
        environment: {'USERPROFILE': r'C:\Users\user'},
        operatingSystem: 'windows',
      );

      expect(
        paths.configDirectory,
        p.join(r'C:\Users\user', 'AppData', 'Roaming', 'LlamaPulse'),
      );
    });

    test('throws StateError when HOME is missing', () {
      expect(
        () => AppPaths.resolve(environment: {}, operatingSystem: 'linux'),
        throwsStateError,
      );
    });

    test('joins the params file and models directory', () {
      const paths = AppPaths(configDirectory: '/config/dir');

      expect(paths.paramsYamlFile, p.join('/config/dir', 'params.yaml'));
      expect(paths.modelsDirectory, p.join('/config/dir', 'models'));
    });
  });
}
