import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<Directory> createTempDirectory() async {
  final directory = await Directory.systemTemp.createTemp('llama_pulse_scan_');
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return directory;
}

void main() {
  late Directory root;
  late Directory nested;
  late ModelFileScanner scanner;

  setUp(() async {
    root = await createTempDirectory();
    nested = await Directory(p.join(root.path, 'nested')).create();
    await File(p.join(root.path, 'a.gguf')).writeAsString('a');
    await File(p.join(root.path, 'b.GGUF')).writeAsString('b');
    await File(p.join(root.path, 'c.bin')).writeAsString('c');
    await File(p.join(nested.path, 'nested.gguf')).writeAsString('nested');
    scanner = const ModelFileScanner();
  });

  test('matches gguf case-insensitively and ignores the subdirectory by '
      'default', () async {
    final result = await scanner.scan(directories: [root.path]);

    expect(
      result.files.map((file) => file.fileName),
      unorderedEquals(['a.gguf', 'b.GGUF']),
    );
    expect(result.warnings, isEmpty);
  });

  test('walks subdirectories when recursive', () async {
    final result = await scanner.scan(
      directories: [root.path],
      recursive: true,
    );

    expect(
      result.files.map((file) => file.fileName),
      unorderedEquals(['a.gguf', 'b.GGUF', 'nested.gguf']),
    );
  });

  test('deduplicates a file reachable through two roots', () async {
    final result = await scanner.scan(
      directories: [root.path, nested.path],
      recursive: true,
    );

    expect(
      result.files.where((file) => file.fileName == 'nested.gguf'),
      hasLength(1),
    );
  });

  test('warns about a missing directory without throwing', () async {
    final missing = p.join(root.path, 'missing');

    final result = await scanner.scan(directories: [missing]);

    expect(result.files, isEmpty);
    expect(result.warnings, ['$missing is not a readable directory']);
  });

  test('sorts by lower-cased file name', () async {
    await File(p.join(root.path, 'zeta.gguf')).writeAsString('z');
    await File(p.join(root.path, 'Alpha.gguf')).writeAsString('A');
    await File(p.join(root.path, 'beta.gguf')).writeAsString('beta');

    final result = await scanner.scan(directories: [root.path]);

    expect(result.files.map((file) => file.fileName), [
      'a.gguf',
      'Alpha.gguf',
      'b.GGUF',
      'beta.gguf',
      'zeta.gguf',
    ]);
  });

  test('returns unmodifiable lists', () async {
    final result = await scanner.scan(directories: [root.path]);

    expect(() => result.files.add(result.files.first), throwsUnsupportedError);
    expect(() => result.warnings.add('x'), throwsUnsupportedError);
  });

  test('inspect returns null for a non-gguf file', () async {
    final useCase = InspectModel(scanner);

    expect(await useCase(p.join(root.path, 'c.bin')), isNull);
  });

  test('inspect returns metadata for an existing gguf file', () async {
    final path = p.join(root.path, 'a.gguf');
    final useCase = InspectModel(scanner);

    final info = await useCase(path);

    expect(info, isNotNull);
    expect(info!.fileName, 'a.gguf');
    expect(info.sizeBytes, 1);
    expect(p.isAbsolute(info.path), isTrue);
  });

  test('inspect returns null for a missing file', () async {
    final useCase = InspectModel(scanner);

    expect(await useCase(p.join(root.path, 'missing.gguf')), isNull);
  });
}
