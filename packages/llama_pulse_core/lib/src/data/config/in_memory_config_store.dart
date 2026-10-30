import '../../domain/gateways/config_store.dart';

/// A [ConfigStore] backed by an in-memory map.
///
/// Documents are deep-copied on read and write, so callers can never mutate the
/// stored state through a returned or supplied map.
final class InMemoryConfigStore implements ConfigStore {
  final Map<String, Map<String, Object?>> _documents = {};

  @override
  Future<Map<String, Object?>?> read(String name) async {
    final stored = _documents[name];
    return stored == null ? null : _copyMap(stored);
  }

  @override
  Future<void> write(String name, Map<String, Object?> data) async {
    _documents[name] = _copyMap(data);
  }

  @override
  Future<void> delete(String name) async {
    _documents.remove(name);
  }

  static Map<String, Object?> _copyMap(Map<String, Object?> source) => {
    for (final entry in source.entries) entry.key: _copyValue(entry.value),
  };

  static Object? _copyValue(Object? value) {
    if (value is Map<String, Object?>) {
      return _copyMap(value);
    }
    if (value is List<Object?>) {
      return <Object?>[for (final item in value) _copyValue(item)];
    }
    return value;
  }
}
