import 'dart:io';

import 'package:built_value/serializer.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/runtime_index.dart';
import '../config/yaml_decoder.dart';

/// Reads `runtime/index.yaml` for the two loaders that resolve paths.
///
/// [YamlRuntimeStore] owns every mutation; this helper only parses, and unlike
/// the store it also offers a synchronous read because
/// `LlamaLibraryLocator.candidates` is a getter. A missing, unreadable,
/// malformed or stale document reads as [RuntimeIndex.empty], so a corrupt
/// index degrades to "no managed runtime" instead of blocking a launch.
abstract final class RuntimeIndexFile {
  /// File name of the index inside the runtime root.
  static const String name = 'index.yaml';

  /// Absolute index path under [runtimeRoot].
  static String pathFor(String runtimeRoot) => p.join(runtimeRoot, name);

  /// Parses [file], or returns [RuntimeIndex.empty] when it is unusable.
  static RuntimeIndex readSync(File file, Serializers serializers) {
    try {
      if (!file.existsSync()) {
        return RuntimeIndex.empty();
      }
      return _decode(file.readAsStringSync(), serializers);
    } on Object {
      return RuntimeIndex.empty();
    }
  }

  /// Parses [file], or returns [RuntimeIndex.empty] when it is unusable.
  static Future<RuntimeIndex> read(File file, Serializers serializers) async {
    try {
      if (!await file.exists()) {
        return RuntimeIndex.empty();
      }
      return _decode(await file.readAsString(), serializers);
    } on Object {
      return RuntimeIndex.empty();
    }
  }

  static RuntimeIndex _decode(String yaml, Serializers serializers) {
    final document = YamlDecoder.decode(yaml);
    if (document['schemaVersion'] != RuntimeIndex.schemaVersion) {
      return RuntimeIndex.empty();
    }
    final body = Map<String, Object?>.from(document)..remove('schemaVersion');
    return serializers.deserializeWith(RuntimeIndex.serializer, body) ??
        RuntimeIndex.empty();
  }
}
