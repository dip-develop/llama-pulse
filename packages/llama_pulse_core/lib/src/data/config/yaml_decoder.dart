import 'package:yaml/yaml.dart';

/// Converts YAML source into plain Dart collections.
///
/// Hand-written because `built_value` serializers must never see `YamlMap` or
/// `YamlList` nodes: they are unmodifiable views with non-`String` keys and
/// their own equality, and the generated deserializers expect ordinary
/// `Map<String, Object?>` and `List<Object?>` values.
abstract final class YamlDecoder {
  /// Parses [source] into a plain map.
  ///
  /// Throws [FormatException] when the document is invalid YAML, has a
  /// non-mapping root, or contains a non-string mapping key.
  static Map<String, Object?> decode(String source) {
    final Object? root;
    try {
      root = loadYaml(source) as Object?;
    } on YamlException catch (error) {
      throw FormatException('Invalid YAML: ${error.message}');
    }
    if (root is! Map<Object?, Object?>) {
      throw const FormatException('YAML root must be a mapping');
    }
    return _map(root, 'root');
  }

  static Map<String, Object?> _map(Map<Object?, Object?> source, String path) {
    final result = <String, Object?>{};
    for (final entry in source.entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException('Non-string key at $path: $key');
      }
      result[key] = _value(entry.value, '$path.$key');
    }
    return result;
  }

  static Object? _value(Object? value, String path) {
    if (value is Map<Object?, Object?>) {
      return _map(value, path);
    }
    if (value is List<Object?>) {
      return <Object?>[
        for (var index = 0; index < value.length; index++)
          _value(value[index], '$path[$index]'),
      ];
    }
    return value;
  }
}
