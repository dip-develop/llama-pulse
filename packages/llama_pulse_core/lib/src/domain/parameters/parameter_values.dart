import 'package:built_collection/built_collection.dart';

import '../entities/model_params.dart';
import '../entities/server_config.dart';
import 'parameter_catalog.dart';

/// Helpers for the catalog value map stored on [ServerConfig] and
/// [ModelParams].
abstract final class ParameterValues {
  /// Returns [current] with [id] set to [value], or without [id] when [value]
  /// is `null`.
  static BuiltMap<String, String> set(
    BuiltMap<String, String> current,
    String id,
    String? value,
  ) {
    final builder = current.toBuilder();
    if (value == null) {
      builder.remove(id);
    } else {
      builder[id] = value;
    }
    return builder.build();
  }

  /// Returns [current] without [id].
  static BuiltMap<String, String> remove(
    BuiltMap<String, String> current,
    String id,
  ) => (current.toBuilder()..remove(id)).build();

  /// Returns [current] in catalog order, with unknown ids at the end.
  ///
  /// Catalog order keeps the YAML document stable regardless of insertion
  /// order. Unknown ids are kept, sorted by id, instead of being dropped: the
  /// validator reports them, but normalizing must not lose data.
  static BuiltMap<String, String> normalized(BuiltMap<String, String> current) {
    final catalog = ParameterCatalog.v080;
    final knownIds = {for (final spec in catalog.parameters) spec.id};
    final result = <String, String>{};
    for (final spec in catalog.parameters) {
      final value = current[spec.id];
      if (value != null) {
        result[spec.id] = value;
      }
    }
    final unknown = [
      for (final id in current.keys)
        if (!knownIds.contains(id)) id,
    ]..sort();
    for (final id in unknown) {
      final value = current[id];
      if (value != null) {
        result[id] = value;
      }
    }
    return BuiltMap<String, String>(result);
  }

  /// Returns the ids in [current] whose value is not the default.
  ///
  /// [isDefault] decides per parameter; the result follows catalog order, with
  /// unknown ids last.
  static List<String> modifiedIds(
    BuiltMap<String, String> current, {
    required bool Function(String id, String? value) isDefault,
  }) => [
    for (final entry in normalized(current).entries)
      if (!isDefault(entry.key, entry.value)) entry.key,
  ];

  /// Returns the typed field that owns [id], or `null`.
  static String? ownerOf(String id) => ParameterCatalog.v080.byId(id)?.owner;

  /// Returns the effective value of [id] for [config].
  ///
  /// A typed owner wins; otherwise the value comes from [ServerConfig.params].
  static String? valueFor(ServerConfig config, String id) {
    final typed = _serverValue(config, ownerOf(id));
    return typed ?? config.params[id];
  }

  /// Returns the effective value of [id] for [params].
  ///
  /// A typed sampling field wins; otherwise the value comes from
  /// [ModelParams.params].
  static String? valueForModel(ModelParams params, String id) {
    final typed = switch (id) {
      'model' => params.modelPath,
      'ctx-size' => '${params.contextSize}',
      'gpu-layers' => '${params.gpuLayers}',
      'threads' => '${params.threads}',
      'temp' => _double(params.temperature),
      'top-p' => _double(params.topP),
      'top-k' => '${params.topK}',
      'predict' => '${params.maxTokens}',
      _ => null,
    };
    return typed ?? params.params[id];
  }

  static String? _serverValue(ServerConfig config, String? owner) =>
      switch (owner) {
        'modelPath' => config.modelPath,
        'host' => config.host,
        'port' => '${config.port}',
        'contextSize' => '${config.contextSize}',
        'threads' => '${config.threads}',
        'gpuLayers' => '${config.gpuLayers}',
        'parallelSlots' => '${config.parallelSlots}',
        'modelAlias' => config.modelAlias,
        'apiKey' => config.apiKey,
        'flashAttention' => config.flashAttention.name,
        'mlock' => config.mlock ? 'true' : 'false',
        'mmap' => config.mmap ? 'true' : 'false',
        'extraArgs' => config.extraArgs.join('\n'),
        _ => null,
      };

  static String _double(double value) => value.toString();
}
