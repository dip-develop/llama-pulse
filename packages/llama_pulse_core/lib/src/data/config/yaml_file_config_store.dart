import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/gateways/config_store.dart';
import 'yaml_decoder.dart';
import 'yaml_encoder.dart';

/// A [ConfigStore] that keeps one YAML file per document.
final class YamlFileConfigStore implements ConfigStore {
  /// Creates a store rooted at [directory].
  factory YamlFileConfigStore({required String directory}) =>
      YamlFileConfigStore._(directory);

  YamlFileConfigStore._(this._directory);

  final String _directory;

  static final RegExp _namePattern = RegExp(r'^[a-z0-9_]+$');

  @override
  Future<Map<String, Object?>?> read(String name) async {
    final file = _fileFor(name);
    if (!await file.exists()) {
      return null;
    }
    final source = await file.readAsString();
    try {
      return YamlDecoder.decode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid YAML in ${file.path}: ${error.message}');
    }
  }

  @override
  Future<void> write(String name, Map<String, Object?> data) async {
    final file = _fileFor(name);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(YamlEncoder.encode(data), flush: true);
    try {
      await temporary.rename(file.path);
    } on FileSystemException {
      // Windows cannot rename over an existing file; delete first, which is
      // not atomic.
      if (await file.exists()) {
        await file.delete();
      }
      await temporary.rename(file.path);
    }
  }

  @override
  Future<void> delete(String name) async {
    final file = _fileFor(name);
    if (await file.exists()) {
      await file.delete();
    }
  }

  File _fileFor(String name) {
    if (!_namePattern.hasMatch(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'must be a lowercase file stem matching ^[a-z0-9_]+\$',
      );
    }
    return File(p.join(_directory, '$name.yaml'));
  }
}
