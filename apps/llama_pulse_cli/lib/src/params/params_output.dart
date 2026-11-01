import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Version of the embedded params command output schema.
const int paramsOutputSchemaVersion = 1;

/// Returns the ids whose effective value differs from the default for
/// [params], in catalog order, with unknown stored ids last.
///
/// Typed fields are compared with the value of the same field on
/// [ModelParams.defaults], so `threads: 8` is reported even though the catalog
/// default for `threads` is dynamic. Map-backed values use
/// [ParameterValueCodec.isDefault], so `seed=-1` or `batch-size=2048` stay
/// hidden.
List<String> modifiedModelParameterIds(ModelParams params) {
  final catalog = ParameterCatalog.v080;
  final defaults = ModelParams.defaults();
  final ids = <String>[];
  final known = <String>{};
  for (final spec in catalog.parameters) {
    known.add(spec.id);
    if (!spec.appliesTo(ParamSurface.embedded)) {
      continue;
    }
    final value = ParameterValues.valueForModel(params, spec.id);
    if (value == null || value.isEmpty) {
      continue;
    }
    final isDefault = _hasTypedModelField(spec.id)
        ? value == ParameterValues.valueForModel(defaults, spec.id)
        : ParameterValueCodec.isDefault(spec, value);
    if (!isDefault) {
      ids.add(spec.id);
    }
  }
  final unknown = [
    for (final id in params.params.keys)
      if (!known.contains(id)) id,
  ]..sort();
  return [...ids, ...unknown];
}

/// Extends a `params.yaml` document with the additive `--json` keys.
///
/// `params` is the typed field map the document already carries; adding an
/// entry for the catalog map would replace it, so the catalog values stay at
/// `params.params` as they do on disk. `modified` is the new key.
Map<String, Object?> encodeParamsDocument({
  required Map<String, Object?> document,
  required ModelParams params,
}) => {...document, 'modified': modifiedModelParameterIds(params)};

/// Whether [id] is stored in a typed [ModelParams] field.
bool _hasTypedModelField(String id) => const {
  'ctx-size',
  'threads',
  'gpu-layers',
  'temp',
  'top-k',
  'top-p',
  'chat-template',
}.contains(id);
