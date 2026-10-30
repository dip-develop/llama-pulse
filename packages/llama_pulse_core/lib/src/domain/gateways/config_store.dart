/// Persistence for named configuration documents.
///
/// A [name] is a file stem without extension. Implementations decide the
/// on-disk format; the shipped file-backed store uses YAML.
abstract interface class ConfigStore {
  /// Reads the document stored under [name], or `null` when it is absent.
  Future<Map<String, Object?>?> read(String name);

  /// Replaces the document stored under [name].
  Future<void> write(String name, Map<String, Object?> data);

  /// Removes the document stored under [name], if present.
  Future<void> delete(String name);
}
