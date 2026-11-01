import 'package:args/args.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Registers the repeatable `--param` option shared by the embedded commands.
///
/// The help text matches the server's `--param` so the two surfaces document
/// the same syntax.
void addParamOption(ArgParser parser) {
  parser.addMultiOption(
    'param',
    splitCommas: false,
    valueHelp: 'id|id=value',
    help:
        'Set an embedded catalog parameter. `id=value` sets it, `id=` removes '
        'it and a bare `id` sets a boolean to true. Repeatable only for '
        'repeatable parameters. See `llamapulse params catalog --surface '
        'embedded` and `llamapulse params describe <id>`.',
  );
}

/// The parsed `--param` arguments.
final class ParsedParamArguments {
  /// Creates a parse result; [errors] is empty when every value parsed.
  const ParsedParamArguments({required this.overrides, required this.errors});

  /// Catalog values keyed by catalog id.
  ///
  /// An empty value means "remove the stored value". A repeatable parameter
  /// keeps its occurrences newline-separated.
  final Map<String, String> overrides;

  /// One message per `--param` argument that could not be parsed.
  final List<String> errors;

  /// Whether any `--param` value survived parsing.
  bool get hasOverrides => overrides.isNotEmpty;
}

/// Parses the repeatable `--param` arguments on [args].
///
/// `id=value` sets a value, `id=` removes it and a bare `id` sets a boolean to
/// true. Repeating a non-repeatable id is an error, because the last value
/// would silently win.
ParsedParamArguments parseParamArguments(ArgResults args) {
  final catalog = ParameterCatalog.v080;
  final overrides = <String, String>{};
  final errors = <String>[];
  final rawParams = args.wasParsed('param')
      ? args.multiOption('param')
      : const <String>[];

  for (final raw in rawParams) {
    final equals = raw.indexOf('=');
    final id = (equals < 0 ? raw : raw.substring(0, equals)).trim();
    if (id.isEmpty) {
      errors.add("invalid value for --param: '$raw' (expected id=value)");
      continue;
    }

    final spec = catalog.byId(id);
    String value;
    if (equals < 0) {
      if (spec != null && spec.type != ParamValueType.bool) {
        errors.add(
          "invalid value for --param: '$id' is not a boolean; use $id=value",
        );
        continue;
      }
      value = 'true';
    } else {
      value = raw.substring(equals + 1);
    }

    final current = overrides[id];
    if (spec != null && !spec.repeatable && current != null) {
      errors.add("invalid value for --param: '$id' is not repeatable");
      continue;
    }

    if (spec != null &&
        spec.repeatable &&
        value.isNotEmpty &&
        current != null) {
      overrides[id] = current.isEmpty ? value : '$current\n$value';
    } else {
      overrides[id] = value;
    }
  }

  return ParsedParamArguments(overrides: overrides, errors: errors);
}

/// The result of applying typed flags and `--param` values to [ModelParams].
final class ResolvedEmbeddedParams {
  /// Creates a resolution result; [errors] is empty when every value applied.
  const ResolvedEmbeddedParams({required this.params, required this.errors});

  /// The resulting parameters. With errors they are only a preview and must
  /// not be persisted or handed to the engine.
  final ModelParams params;

  /// One message per rejected `--param` value.
  final List<String> errors;
}

/// Applies [paramOverrides] to [params].
///
/// Typed flags are applied by the caller first; [typedValues] carries their
/// canonical values so a conflicting `--param` can be reported. An id in
/// [_embeddedTypedFields] writes the matching [ModelParams] field instead of
/// the catalog map: `--param threads=8` stores `threads: 8`, never a `params`
/// entry. Such an id is accepted even though the catalog marks it managed,
/// because the typed field is the one place the embedded path reads it from.
///
/// Every other id goes through [ParameterValidator] with
/// [ParamSurface.embedded], so managed ids without a typed field, unsupported
/// and removed entries, server-only ids and invalid values are all reported
/// with the validator's wording. This function never saves anything.
ResolvedEmbeddedParams resolveEmbeddedParams({
  required ModelParams params,
  required Map<String, String> paramOverrides,
  Map<String, String> typedValues = const {},
}) {
  final catalog = ParameterCatalog.v080;
  final errors = <String>[];
  var next = params;

  // Validate every map-backed value in one pass so the messages follow catalog
  // order, exactly as they would when the values were already stored.
  var probe = next.params;
  for (final entry in paramOverrides.entries) {
    final spec = catalog.byId(entry.key);
    if (spec != null) {
      if (_embeddedTypedFields.containsKey(spec.id) &&
          spec.appliesTo(ParamSurface.embedded)) {
        continue;
      }
      // An empty value removes a stored value; that is only valid for a
      // configurable parameter. Managed, unsupported and removed ids still go
      // through the validator so they keep their documented message.
      if (entry.value.isEmpty && spec.exposure == ParamExposure.configurable) {
        continue;
      }
    }
    probe = ParameterValues.set(probe, entry.key, entry.value);
  }
  errors.addAll(
    const ParameterValidator().validateValues(
      probe,
      surface: ParamSurface.embedded,
      forStart: false,
    ),
  );

  final mapValues = <String, String?>{};
  for (final entry in paramOverrides.entries) {
    final id = entry.key;
    final raw = entry.value;
    final spec = catalog.byId(id);
    if (spec == null) {
      // The validator reports unknown ids; nothing to canonicalize.
      continue;
    }

    if (_embeddedTypedFields.containsKey(id) &&
        spec.appliesTo(ParamSurface.embedded)) {
      final typed = typedValues[id];
      if (raw.isEmpty) {
        // Removing an owned value restores the typed default, unless the typed
        // flag already supplied a value for this run.
        if (typed == null) {
          next = _applyTyped(next, id, _typedDefault(spec));
        }
        // A hand-edited document may still carry the id in the map; the typed
        // field is authoritative, so the stale entry is dropped.
        next = next.copyWith(params: ParameterValues.remove(next.params, id));
        continue;
      }

      final valueProblems = ParameterValueCodec.validate(
        spec,
        raw,
        forStart: false,
      );
      if (valueProblems.isNotEmpty) {
        errors.addAll(valueProblems);
        continue;
      }
      final canonical = ParameterValueCodec.parse(spec, raw);
      if (canonical == null) {
        continue;
      }
      if (typed != null) {
        if (typed != canonical) {
          errors.add(
            '${_embeddedTypedFields[id]} and --param $id disagree '
            '($typed vs $canonical)',
          );
        }
        // Equal values are already stored through the typed field.
        continue;
      }
      final applied = _applyCanonical(next, id, canonical);
      if (applied.error != null) {
        errors.add(applied.error!);
      } else {
        next = applied.params!;
        // A hand-edited document may still carry the id in the map; the typed
        // field is authoritative, so the stale entry is dropped.
        next = next.copyWith(params: ParameterValues.remove(next.params, id));
      }
      continue;
    }

    if (raw.isEmpty) {
      mapValues[id] = null;
      continue;
    }
    final String? canonical;
    try {
      canonical = ParameterValueCodec.parse(spec, raw);
    } on FormatException {
      // `validateValues` already reported the reason.
      continue;
    }
    if (canonical != null) {
      mapValues[id] = canonical;
    }
  }

  if (errors.isEmpty) {
    var values = next.params;
    for (final entry in mapValues.entries) {
      values = ParameterValues.set(values, entry.key, entry.value);
    }
    next = next.copyWith(params: values);
  }

  return ResolvedEmbeddedParams(params: next, errors: errors);
}

/// Embedded ids with a typed [ModelParams] field and the flag that owns it.
///
/// `chat-template` is typed on [ModelParams] even though the catalog does not
/// give it an owner, so the CLI writes the field instead of the map. `seed`,
/// `min-p` and `batch-size` have no typed field and stay in
/// [ModelParams.params].
const Map<String, String> _embeddedTypedFields = {
  'ctx-size': '--context-size',
  'threads': '--threads',
  'gpu-layers': '--gpu-layers',
  'temp': '--temperature',
  'top-k': '--top-k',
  'top-p': '--top-p',
  'chat-template': '--chat-template',
};

typedef _Applied = ({ModelParams? params, String? error});

/// Returns the canonical default of [spec] for [ModelParams].
String _typedDefault(ParameterSpec spec) =>
    ParameterValues.valueForModel(ModelParams.defaults(), spec.id) ?? '';

/// Writes [canonical] into the [ModelParams] field that owns [id].
_Applied _applyCanonical(ModelParams params, String id, String canonical) =>
    switch (id) {
      'ctx-size' => _applyInt(
        params,
        canonical,
        '--context-size',
        (p, v) => p.copyWith(contextSize: v),
      ),
      'threads' => _applyInt(
        params,
        canonical,
        '--threads',
        (p, v) => p.copyWith(threads: v),
      ),
      'gpu-layers' => _applyInt(
        params,
        canonical,
        '--gpu-layers',
        (p, v) => p.copyWith(gpuLayers: v),
      ),
      'temp' => _applyDouble(
        params,
        canonical,
        '--temperature',
        (p, v) => p.copyWith(temperature: v),
      ),
      'top-k' => _applyInt(
        params,
        canonical,
        '--top-k',
        (p, v) => p.copyWith(topK: v),
      ),
      'top-p' => _applyDouble(
        params,
        canonical,
        '--top-p',
        (p, v) => p.copyWith(topP: v),
      ),
      'chat-template' => (
        params: params.copyWith(
          chatTemplate: canonical.isEmpty ? null : canonical,
        ),
        error: null,
      ),
      _ => (params: params, error: null),
    };

/// Applies [value] when it parses, otherwise reports a typed-field mismatch.
_Applied _applyInt(
  ModelParams params,
  String value,
  String flag,
  ModelParams Function(ModelParams params, int value) apply,
) {
  final parsed = int.tryParse(value);
  return parsed == null
      ? (params: null, error: "$flag must be an integer: '$value'")
      : (params: apply(params, parsed), error: null);
}

/// Applies [value] when it parses, otherwise reports a typed-field mismatch.
_Applied _applyDouble(
  ModelParams params,
  String value,
  String flag,
  ModelParams Function(ModelParams params, double value) apply,
) {
  final parsed = double.tryParse(value);
  return parsed == null
      ? (params: null, error: "$flag must be a number: '$value'")
      : (params: apply(params, parsed), error: null);
}

/// Writes [canonical] into the [ModelParams] field that owns [id].
ModelParams _applyTyped(ModelParams params, String id, String canonical) {
  final applied = _applyCanonical(params, id, canonical);
  return applied.params ?? params;
}
