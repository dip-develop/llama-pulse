import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// The four bytes every ELF file starts with.
const List<int> elfMagic = <int>[0x7f, 0x45, 0x4c, 0x46];

/// A little-endian 64-bit Mach-O magic.
const List<int> machoMagic = <int>[0xcf, 0xfa, 0xed, 0xfe];

/// Builds the tar.gz fixture that mirrors a real `llama-b11960/` archive.
///
/// It has an executable with an ELF header, a versioned library, the usual
/// unversioned symlink to it, and a readme. Nothing here is big enough to
/// matter; the downloader and extractor under test are what make it safe.
Uint8List normalTarGz() {
  final archive = Archive()
    ..add(ArchiveFile.directory('llama-b11960/'))
    ..add(
      ArchiveFile.bytes('llama-b11960/llama-server', <int>[
        ...elfMagic,
        ...utf8.encode('server-payload'),
      ]),
    )
    ..add(
      ArchiveFile.bytes('llama-b11960/libllama.so.0', <int>[
        ...elfMagic,
        ...utf8.encode('library-payload'),
      ]),
    )
    ..add(ArchiveFile.symlink('llama-b11960/libllama.so', 'libllama.so.0'))
    ..add(
      ArchiveFile.bytes('llama-b11960/README.md', utf8.encode('# llama.cpp\n')),
    );
  return tarGzArchive(archive);
}

/// Builds the zip fixture that mirrors a real Windows runtime archive.
Uint8List normalZip() {
  final archive = Archive()
    ..add(
      ArchiveFile.bytes('llama-b11960/llama-server.exe', <int>[
        0x4d,
        0x5a,
        ...utf8.encode('server-payload'),
      ]),
    )
    ..add(
      ArchiveFile.bytes('llama-b11960/ggml-cpu.dll', <int>[
        0x4d,
        0x5a,
        ...utf8.encode('library-payload'),
      ]),
    )
    ..add(
      ArchiveFile.bytes('llama-b11960/README.md', utf8.encode('# llama.cpp\n')),
    );
  return zipArchive(archive);
}

/// Builds the tar.gz fixture that carries a CUDA runtime tree.
Uint8List cudartTarGz() {
  final archive = Archive()
    ..add(ArchiveFile.directory('cudart-llama-b11960-bin-ubuntu-x64/'))
    ..add(
      ArchiveFile.bytes(
        'cudart-llama-b11960-bin-ubuntu-x64/libcudart.so.12',
        <int>[...elfMagic, ...utf8.encode('cudart-payload')],
      ),
    );
  return tarGzArchive(archive);
}

/// Encodes [entries] as a gzip-compressed tar.
Uint8List tarGzEntries(List<ArchiveFile> entries) {
  final archive = Archive();
  for (final entry in entries) {
    archive.add(entry);
  }
  return tarGzArchive(archive);
}

/// Encodes [entries] as a zip.
Uint8List zipEntries(List<ArchiveFile> entries) {
  final archive = Archive();
  for (final entry in entries) {
    archive.add(entry);
  }
  return zipArchive(archive);
}

/// Builds a tar.gz with two entries that share one name.
///
/// [Archive.add] replaces a duplicate by name, which is exactly what a real
/// malicious archive does not do, so the two tar bodies are spliced together
/// without the first one's end-of-archive marker.
Uint8List duplicateEntryTarGz() {
  final first = TarEncoder().encodeBytes(
    Archive()..add(
      ArchiveFile.bytes('llama-b11960/duplicate.txt', utf8.encode('first')),
    ),
  );
  final second = TarEncoder().encodeBytes(
    Archive()..add(
      ArchiveFile.bytes('llama-b11960/duplicate.txt', utf8.encode('second')),
    ),
  );
  // TarEncoder always writes a 1024-byte zero end marker.
  final spliced = <int>[...first.sublist(0, first.length - 1024), ...second];
  return gzip(spliced);
}

/// Builds a tar.gz with one file and a hard link to it.
Uint8List hardLinkTarGz() {
  final first = TarEncoder().encodeBytes(
    Archive()..add(
      ArchiveFile.bytes('llama-b11960/target.txt', utf8.encode('target')),
    ),
  );
  final link = TarFile()
    ..filename = 'llama-b11960/link.txt'
    ..typeFlag = TarFile.hardLink
    ..nameOfLinkedFile = 'llama-b11960/target.txt'
    ..mode = 0x1a4
    ..lastModTime = 0;
  final header = OutputMemoryStream();
  link.write(header);
  final spliced = <int>[
    ...first.sublist(0, first.length - 1024),
    ...header.getBytes(),
    ...Uint8List(1024),
  ];
  return gzip(spliced);
}

/// Builds a zip with [count] files under one top-level directory.
Uint8List manyEntriesZip(int count) {
  final archive = Archive();
  for (var index = 0; index < count; index++) {
    archive.add(
      ArchiveFile.bytes('llama-b11960/file-$index.txt', <int>[index & 0xff]),
    );
  }
  return zipArchive(archive);
}

/// Compresses [bytes] as gzip.
Uint8List gzip(List<int> bytes) =>
    Uint8List.fromList(const GZipEncoder().encodeBytes(bytes));

/// Encodes [archive] as a gzip-compressed tar.
Uint8List tarGzArchive(Archive archive) =>
    gzip(TarEncoder().encodeBytes(archive));

/// Encodes [archive] as a zip without spending time compressing fixtures.
Uint8List zipArchive(Archive archive) => Uint8List.fromList(
  ZipEncoder().encodeBytes(archive, level: DeflateLevel.none),
);

/// Lower-case hex SHA-256 of [bytes].
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();
