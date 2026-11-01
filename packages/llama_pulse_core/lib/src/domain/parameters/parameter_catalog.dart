import '../entities/parameter_spec.dart';

part 'parameter_catalog.generated.dart';

/// The `llama.cpp` parameter catalog known to LlamaPulse.
///
/// One instance describes one upstream tag. The generated body lives in
/// `parameter_catalog.generated.dart`; [v080] is the catalog for the pinned
/// `v0.8.0` release.
final class ParameterCatalog {
  const ParameterCatalog._({
    required this.upstreamTag,
    required this.upstreamCommit,
    required this.upstreamFileSha256,
    required this.digest,
    required this.groups,
    required this.parameters,
  });

  /// Catalog for the pinned `llama.cpp` tag `v0.8.0`.
  static const ParameterCatalog v080 = _catalogV080;

  /// Upstream tag the catalog was generated from, for example `v0.8.0`.
  final String upstreamTag;

  /// Upstream commit the tag points at.
  final String upstreamCommit;

  /// SHA-256 of the vendored `common/arg.cpp`.
  final String upstreamFileSha256;

  /// Digest of the catalog body; see `catalog_digest.dart`.
  final String digest;

  /// Every presentation group, ordered by [ParameterGroupSpec.order].
  final List<ParameterGroupSpec> groups;

  /// Every parameter in upstream declaration order.
  final List<ParameterSpec> parameters;

  static final Map<String, ParameterSpec> _byId = {
    for (final parameter in v080.parameters) parameter.id: parameter,
  };

  static final Map<String, ParameterSpec> _byFlag = {
    for (final parameter in v080.parameters)
      for (final flag in parameter.flags) flag: parameter,
    for (final parameter in v080.parameters) ?parameter.negatedFlag: parameter,
  };

  /// Every parameter in upstream declaration order.
  List<ParameterSpec> get all => parameters;

  /// Looks a parameter up by [ParameterSpec.id].
  ParameterSpec? byId(String id) => _byId[id];

  /// Looks a parameter up by any flag token, including the negated form.
  ParameterSpec? byFlag(String flag) => _byFlag[flag];

  /// Returns the parameters that can be applied to [surface], in catalog
  /// order.
  List<ParameterSpec> forSurface(ParamSurface surface) => [
    for (final parameter in parameters)
      if (parameter.appliesTo(surface)) parameter,
  ];
}
