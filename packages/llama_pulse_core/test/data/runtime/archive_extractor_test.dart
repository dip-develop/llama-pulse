import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/runtime/archive_fixtures.dart';

const int _defaultMaxTotalBytes = 3 * 1024 * 1024 * 1024;

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('llama_extract_');
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  Future<File> archiveFile(String name, Uint8List bytes) async {
    final file = File(p.join(workspace.path, name));
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Directory> destination() async {
    final directory = Directory(p.join(workspace.path, 'out'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<int> extract(
    String name,
    Uint8List bytes, {
    int maxEntries = 2000,
    int maxTotalBytes = _defaultMaxTotalBytes,
  }) async {
    final destinationDirectory = await destination();
    return const ArchiveExtractor().extract(
      archive: await archiveFile(name, bytes),
      assetName: name,
      destination: destinationDirectory,
      maxEntries: maxEntries,
      maxTotalBytes: maxTotalBytes,
    );
  }

  Matcher unsafeArchive() => throwsA(
    isA<RuntimeException>().having(
      (error) => error.code,
      'code',
      RuntimeFailureCode.unsafeArchive,
    ),
  );

  group('tar.gz', () {
    test('extracts files, permissions and an in-tree symlink', () async {
      final count = await extract('llama.tar.gz', normalTarGz());
      final destinationDirectory = Directory(p.join(workspace.path, 'out'));

      expect(count, 3);
      expect(
        File(p.join(destinationDirectory.path, 'llama-server')).existsSync(),
        isTrue,
      );
      expect(
        await File(p.join(destinationDirectory.path, 'README.md'))
            .readAsString(),
        '# llama.cpp\n',
      );

      final server = File(p.join(destinationDirectory.path, 'llama-server'));
      final library = File(p.join(destinationDirectory.path, 'libllama.so.0'));
      final readme = File(p.join(destinationDirectory.path, 'README.md'));
      expect(FileStat.statSync(server.path).mode & 0x1ff, 0x1ed); // 0755
      expect(FileStat.statSync(library.path).mode & 0x1ff, 0x1ed); // 0755
      expect(FileStat.statSync(readme.path).mode & 0x1ff, 0x1a4); // 0644

      final link = Link(p.join(destinationDirectory.path, 'libllama.so'));
      expect(link.existsSync(), isTrue);
      expect(link.targetSync(), 'libllama.so.0');
    });

    test('rejects a path with a parent segment', () async {
      final bytes = tarGzEntries(<ArchiveFile>[
        ArchiveFile.bytes('llama-b11960/ok.txt', <int>[1]),
        ArchiveFile.bytes('llama-b11960/../evil.txt', <int>[2]),
      ]);

      await expectLater(extract('llama.tar.gz', bytes), unsafeArchive());
    });

    test('rejects an absolute path', () async {
      final bytes = tarGzEntries(<ArchiveFile>[
        ArchiveFile.bytes('/etc/passwd', <int>[1]),
      ]);

      await expectLater(extract('llama.tar.gz', bytes), unsafeArchive());
    });

    test('rejects a backslash path', () async {
      final bytes = tarGzEntries(<ArchiveFile>[
        ArchiveFile.bytes('llama-b11960\\evil.txt', <int>[1]),
      ]);

      await expectLater(extract('llama.tar.gz', bytes), unsafeArchive());
    });

    test('rejects a symlink that escapes the destination', () async {
      final bytes = tarGzEntries(<ArchiveFile>[
        ArchiveFile.bytes('llama-b11960/ok.txt', <int>[1]),
        ArchiveFile.symlink('llama-b11960/libevil.so', '../../etc/passwd'),
      ]);

      await expectLater(extract('llama.tar.gz', bytes), unsafeArchive());
    });

    test('rejects duplicate file entries', () async {
      await expectLater(
        extract('llama.tar.gz', duplicateEntryTarGz()),
        unsafeArchive(),
      );
    });

    test('rejects a hard link', () async {
      await expectLater(
        extract('llama.tar.gz', hardLinkTarGz()),
        unsafeArchive(),
      );
    });

    test('rejects entries under a second top-level directory', () async {
      final bytes = tarGzEntries(<ArchiveFile>[
        ArchiveFile.bytes('llama-b11960/ok.txt', <int>[1]),
        ArchiveFile.bytes('other/evil.txt', <int>[2]),
      ]);

      await expectLater(extract('llama.tar.gz', bytes), unsafeArchive());
    });

    test('rejects an archive with no top-level directory', () async {
      final bytes = tarGzEntries(<ArchiveFile>[
        ArchiveFile.bytes('evil.txt', <int>[1]),
      ]);

      await expectLater(extract('llama.tar.gz', bytes), unsafeArchive());
    });
  });

  group('zip', () {
    test('extracts files and marks .exe executable', () async {
      final count = await extract('llama.zip', normalZip());
      final destinationDirectory = Directory(p.join(workspace.path, 'out'));

      expect(count, 3);
      final server = File(
        p.join(destinationDirectory.path, 'llama-server.exe'),
      );
      final library = File(p.join(destinationDirectory.path, 'ggml-cpu.dll'));
      final readme = File(p.join(destinationDirectory.path, 'README.md'));
      expect(server.existsSync(), isTrue);
      expect(FileStat.statSync(server.path).mode & 0x1ff, 0x1ed); // 0755
      expect(FileStat.statSync(library.path).mode & 0x1ff, 0x1a4); // 0644
      expect(FileStat.statSync(readme.path).mode & 0x1ff, 0x1a4); // 0644
    });

    test('rejects more than maxEntries', () async {
      await expectLater(
        extract('llama.zip', manyEntriesZip(2001)),
        unsafeArchive(),
      );
    });

    test('rejects more than maxTotalBytes', () async {
      final bytes = zipEntries(<ArchiveFile>[
        ArchiveFile.bytes('llama-b11960/a.bin', List<int>.filled(30, 1)),
        ArchiveFile.bytes('llama-b11960/b.bin', List<int>.filled(30, 2)),
      ]);

      await expectLater(
        extract('llama.zip', bytes, maxTotalBytes: 50),
        unsafeArchive(),
      );
    });
  });
}
