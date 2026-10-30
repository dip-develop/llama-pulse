import 'dart:convert';
import 'dart:io';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

String _join(String directory, String name) =>
    '$directory${Platform.pathSeparator}$name';

void main() {
  late Directory tempDirectory;
  late StringBuffer out;
  late StringBuffer err;
  late LlamaPulseCommandRunner runner;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('llamapulse_cli_');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    out = StringBuffer();
    err = StringBuffer();
    runner = LlamaPulseCommandRunner(
      CliServices(
        paths: AppPaths(configDirectory: tempDirectory.path),
        configStore: InMemoryConfigStore(),
        out: out,
        err: err,
      ),
    );
  });

  Future<void> writeModel(String name) async {
    final file = File(_join(tempDirectory.path, name));
    await file.writeAsString('gguf');
  }

  test('models list finds .gguf files and ignores others', () async {
    await writeModel('a.gguf');
    await writeModel('b.GGUF');
    await writeModel('c.bin');

    expect(
      await runner.run(['models', 'list', '--dir', tempDirectory.path]),
      ExitCodes.ok,
    );

    final lines = out.toString().split('\n').where((line) => line.isNotEmpty);
    expect(lines.length, 2);
    expect(out.toString(), contains('a.gguf'));
    expect(out.toString(), contains('b.GGUF'));
    expect(out.toString(), isNot(contains('c.bin')));
    expect(err.toString(), isEmpty);
  });

  test('models list --json prints one parseable object', () async {
    await writeModel('a.gguf');

    expect(
      await runner.run([
        'models',
        'list',
        '--dir',
        tempDirectory.path,
        '--json',
      ]),
      ExitCodes.ok,
    );

    final decoded = jsonDecode(out.toString().trim()) as Map<String, Object?>;
    expect(decoded['count'], 1);
    final files = decoded['files'] as List<Object?>;
    expect(files.length, 1);
    final file = files.single as Map<String, Object?>;
    expect(file['fileName'], 'a.gguf');
    expect(file['path'], endsWith('a.gguf'));
    expect(file['sizeBytes'], 4);
    expect(file['modifiedAtEpochMs'], isA<int>());
  });

  test('models list warns about a missing directory but succeeds', () async {
    final missing = _join(tempDirectory.path, 'missing');

    expect(
      await runner.run(['models', 'list', '--dir', missing]),
      ExitCodes.ok,
    );

    expect(err.toString(), contains('$missing is not a readable directory'));
    expect(out.toString(), 'No .gguf files found in $missing\n');
  });

  test('models inspect prints the file fields', () async {
    await writeModel('a.gguf');
    final path = _join(tempDirectory.path, 'a.gguf');

    expect(await runner.run(['models', 'inspect', path]), ExitCodes.ok);

    final output = out.toString();
    expect(output, contains('path: '));
    expect(output, contains('fileName: a.gguf'));
    expect(output, contains('sizeMiB: 0.00'));
    expect(output, contains('modified: '));
    expect(output, contains('Z'));
    expect(err.toString(), isEmpty);
  });

  test('models inspect --json prints one parseable object', () async {
    await writeModel('a.gguf');
    final path = _join(tempDirectory.path, 'a.gguf');

    expect(
      await runner.run(['models', 'inspect', path, '--json']),
      ExitCodes.ok,
    );

    final lines = out.toString().split('\n').where((line) => line.isNotEmpty);
    expect(lines.length, 1);
    final decoded = jsonDecode(out.toString().trim()) as Map<String, Object?>;
    expect(
      decoded.keys,
      unorderedEquals(['path', 'fileName', 'sizeMiB', 'modified']),
    );
    expect(decoded['path'], endsWith('a.gguf'));
    expect(decoded['fileName'], 'a.gguf');
    expect(decoded['sizeMiB'], 0.0);
    expect(decoded['modified'], endsWith('Z'));
    expect(err.toString(), isEmpty);
  });

  test('models inspect exits with not-found for a missing file', () async {
    final path = _join(tempDirectory.path, 'nope.gguf');

    expect(await runner.run(['models', 'inspect', path]), ExitCodes.notFound);

    expect(err.toString(), 'error: not found: $path\n');
    expect(out.toString(), isEmpty);
  });

  test('models inspect exits with not-found for a non-gguf file', () async {
    await writeModel('c.bin');
    final path = _join(tempDirectory.path, 'c.bin');

    expect(await runner.run(['models', 'inspect', path]), ExitCodes.notFound);

    expect(err.toString(), 'error: not found: $path\n');
  });
}
