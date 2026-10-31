import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

final class _FakeExecutor implements ProcessExecutor {
  _FakeExecutor(this.output);

  final ProcessOutput output;
  String? executable;
  List<String>? arguments;

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    return output;
  }
}

void main() {
  group('parseOutput', () {
    test('reads the current version line', () {
      final info = ServerVersionParser.parseOutput(
        '/bin/llama-server',
        'version: 0.8.0 (build 11960, commit 8642541)',
      );

      expect(info.path, '/bin/llama-server');
      expect(info.version, '0.8.0');
      expect(info.buildNumber, 11960);
      expect(info.commit, '8642541');
      expect(info.supported, isTrue);
      expect(info.warning, isNull);
    });

    test('warns for a build below b4000', () {
      final info = ServerVersionParser.parseOutput(
        '/bin/llama-server',
        'version: 0.5.0 (build 1234, commit abc123)',
      );

      expect(info.buildNumber, 1234);
      expect(info.supported, isFalse);
      expect(info.warning, contains('b4000'));
    });

    test('warns when the output has no version prefix but names a fork', () {
      final info = ServerVersionParser.parseOutput(
        '/opt/llama.cpp-rocm/llama-server',
        '0.7.0-dev (build 9999, commit abc)',
      );

      expect(info.version, '0.7.0-dev (build 9999, commit abc)');
      expect(info.buildNumber, isNull);
      expect(info.supported, isTrue);
      expect(info.warning, contains('unsupported or unknown'));
    });

    test('falls back to a bare build number', () {
      final info = ServerVersionParser.parseOutput(
        '/bin/llama-server',
        'b1234',
      );

      expect(info.version, 'b1234');
      expect(info.buildNumber, 1234);
      expect(info.commit, isNull);
      expect(info.supported, isFalse);
      expect(info.warning, contains('b4000'));
    });

    test('accepts a bare build number at or above b4000', () {
      final info = ServerVersionParser.parseOutput('llama-server', 'b5000');

      expect(info.version, 'b5000');
      expect(info.buildNumber, 5000);
      expect(info.supported, isTrue);
      expect(info.warning, isNull);
    });

    test('keeps garbage as the version with a warning', () {
      final info = ServerVersionParser.parseOutput(
        '/bin/llama-server',
        '  some fork build  \n',
      );

      expect(info.version, 'some fork build');
      expect(info.buildNumber, isNull);
      expect(info.supported, isTrue);
      expect(info.warning, isNotNull);
      expect(info.rawOutput, 'some fork build');
    });

    test('handles empty output', () {
      final info = ServerVersionParser.parseOutput('/bin/llama-server', '  ');

      expect(info.version, 'unknown');
      expect(info.buildNumber, isNull);
      expect(info.supported, isTrue);
      expect(info.warning, isNotNull);
    });
  });

  group('parse', () {
    test('runs <path> --version and parses stdout', () async {
      final executor = _FakeExecutor(
        const ProcessOutput(
          exitCode: 0,
          stdout: 'version: 0.8.0 (build 11960, commit 8642541)\n',
          stderr: '',
        ),
      );

      final info = await ServerVersionParser(executor).parse('llama-server');

      expect(executor.executable, 'llama-server');
      expect(executor.arguments, ['--version']);
      expect(info.version, '0.8.0');
      expect(info.buildNumber, 11960);
    });

    test('uses stderr when stdout is empty', () async {
      final executor = _FakeExecutor(
        const ProcessOutput(exitCode: 0, stdout: '', stderr: 'b4321\n'),
      );

      final info = await ServerVersionParser(executor).parse('llama-server');

      expect(info.version, 'b4321');
      expect(info.buildNumber, 4321);
    });

    test('reports a failed executor run without throwing', () async {
      final executor = _FakeExecutor(
        const ProcessOutput(exitCode: 1, stdout: '', stderr: 'boom'),
      );

      final info = await ServerVersionParser(executor).parse('llama-server');

      expect(info.version, 'unknown');
      expect(info.supported, isTrue);
      expect(info.warning, 'could not read llama-server --version');
      expect(info.rawOutput, 'boom');
    });

    test('reports a timed-out executor run without throwing', () async {
      final executor = _FakeExecutor(
        const ProcessOutput(
          exitCode: -1,
          stdout: '',
          stderr: 'timed out after 5s',
        ),
      );

      final info = await ServerVersionParser(executor).parse('llama-server');

      expect(info.version, 'unknown');
      expect(info.warning, 'could not read llama-server --version');
    });
  });
}
