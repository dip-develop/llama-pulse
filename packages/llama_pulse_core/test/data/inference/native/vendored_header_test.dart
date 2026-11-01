import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  late final Directory repoRoot;
  late final Directory pinDirectory;

  setUpAll(() {
    var directory = Directory.current.absolute;
    while (true) {
      final candidate = Directory(
        '${directory.path}/third_party/llama_cpp/v0.8.0',
      );
      if (File('${candidate.path}/SHA256SUMS').existsSync()) {
        repoRoot = directory;
        pinDirectory = candidate;
        return;
      }
      final parent = directory.parent;
      if (parent.path == directory.path) {
        fail(
          'third_party/llama_cpp/v0.8.0/SHA256SUMS not found above '
          '${Directory.current.path}',
        );
      }
      directory = parent;
    }
  });

  test('every vendored file matches SHA256SUMS', () async {
    final lines = File('${pinDirectory.path}/SHA256SUMS').readAsLinesSync()
      ..removeWhere((line) => line.trim().isEmpty);

    expect(lines, hasLength(9));
    for (final line in lines) {
      final match = RegExp(r'^([0-9a-f]{64})  (.+)$').firstMatch(line);
      expect(match, isNotNull, reason: 'malformed line: $line');

      final expected = match!.group(1)!;
      final relativePath = match.group(2)!;
      final file = File('${repoRoot.path}/$relativePath');

      expect(file.existsSync(), isTrue, reason: relativePath);
      final actual = sha256.convert(await file.readAsBytes()).toString();
      expect(actual, expected, reason: relativePath);
    }
  });

  test('PIN.md records the tag and commit', () {
    final pin = File('${pinDirectory.path}/PIN.md').readAsStringSync();

    expect(pin, contains('v0.8.0'));
    expect(pin, contains('8642541b255bfb5dc39cd351a178be09013a55d6'));
    expect(pin, contains('ggml'));
    expect(pin, contains('v0.28.0'));
    expect(pin, contains('source/arg.cpp'));
  });

  test('llama.h has v0.8.0 load fields and no legacy mmap flag', () {
    final header = File('${pinDirectory.path}/include/llama.h')
        .readAsStringSync();

    expect(header, contains('load_mode'));
    expect(header, contains('lazy_mode'));
    expect(header, contains('load_mtp'));
    expect(header, isNot(contains('use_mmap')));
  });
}
