/// Value type of a `llama.cpp` parameter, as understood by LlamaPulse.
///
/// The type is inferred from the upstream handler and value hint, then
/// corrected by the curated override catalog. It describes how a value is
/// stored and validated, not how upstream happens to parse it: several
/// floating-point parameters are declared as `const std::string &` handlers
/// upstream and are still numbers for a user.
enum ParamValueType {
  /// On/off switch. Stored as a `bool`.
  bool('bool'),

  /// Integer value. Stored as an `int`.
  int('int'),

  /// Floating-point value. Stored as a `double`.
  double('double'),

  /// Free-form text. Stored as a `String`.
  string('string'),

  /// Filesystem path. Stored as a `String` and validated for existence when the
  /// parameter requires it.
  path('path'),

  /// One of a fixed allow-list. Stored as a `String`.
  enumeration('enum');

  const ParamValueType(this.wireName);

  /// Name used in the generated YAML catalog.
  final String wireName;

  /// Parses a [wireName].
  ///
  /// Throws [FormatException] for an unknown name so a typo in an override
  /// file fails generation instead of silently falling back.
  static ParamValueType fromWire(String value) => values.firstWhere(
    (type) => type.wireName == value,
    orElse: () => throw FormatException('unknown parameter type: $value'),
  );
}

/// Surface a parameter can be applied to.
enum ParamSurface {
  /// The supervised `llama-server` process.
  server('server'),

  /// The embedded native llama.cpp session inside the worker isolate.
  embedded('embedded');

  const ParamSurface(this.wireName);

  /// Name used in the generated YAML catalog.
  final String wireName;

  /// Parses a [wireName].
  static ParamSurface fromWire(String value) => values.firstWhere(
    (surface) => surface.wireName == value,
    orElse: () => throw FormatException('unknown surface: $value'),
  );
}

/// How LlamaPulse treats a parameter.
enum ParamExposure {
  /// The user can set the value.
  configurable('configurable'),

  /// LlamaPulse owns the value; the user cannot override it.
  managed('managed'),

  /// `llama-server` accepts the flag, but LlamaPulse does not expose it.
  unsupported('unsupported'),

  /// Upstream removed the flag; it is kept in the catalog to explain the
  /// replacement and to catch stale configuration.
  removed('removed');

  const ParamExposure(this.wireName);

  /// Name used in the generated YAML catalog.
  final String wireName;

  /// Parses a [wireName].
  static ParamExposure fromWire(String value) => values.firstWhere(
    (exposure) => exposure.wireName == value,
    orElse: () => throw FormatException('unknown exposure: $value'),
  );
}

/// One `llama.cpp` command-line parameter.
///
/// A single upstream definition can expose several flag tokens (`-c` and
/// `--ctx-size`); [id] is the canonical name and [flags] keeps every token in
/// the order upstream declares it.
final class ParameterSpec {
  /// Creates a parameter specification.
  const ParameterSpec({
    required this.id,
    required this.displayName,
    required this.summary,
    required this.description,
    required this.flags,
    required this.negatedFlag,
    required this.type,
    required this.arity,
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.step,
    required this.allowed,
    required this.itemType,
    required this.repeatable,
    required this.group,
    required this.surfaces,
    required this.exposure,
    required this.owner,
    required this.managedBy,
    required this.envVar,
    required this.advanced,
    required this.deprecated,
    required this.replacement,
    required this.requiresExistingPath,
    required this.warning,
    required this.reason,
  });

  /// Canonical identifier: the first long flag without dashes, or the first
  /// short flag when the definition has no long form.
  final String id;

  /// Human-readable name shown in the UI.
  final String displayName;

  /// One-line explanation, safe to show in a list.
  final String summary;

  /// Full explanation, shown in a detail pane or tooltip.
  final String description;

  /// Every flag token as upstream writes it, for example `['-c',
  /// '--ctx-size']`.
  final List<String> flags;

  /// The `--no-...` counterpart of a boolean switch, when upstream declares
  /// one.
  final String? negatedFlag;

  /// Value type understood by LlamaPulse.
  final ParamValueType type;

  /// Number of values the flag consumes: `0` for switches, `1` for almost
  /// every option, `2` for `--control-vector-layer-range`.
  final int arity;

  /// Upstream default, when it can be stated as a literal.
  ///
  /// `null` means the default is dynamic (derived from the model, the
  /// hardware or another flag) or unknown.
  final Object? defaultValue;

  /// Lower bound for a numeric value, or `null`.
  final num? min;

  /// Upper bound for a numeric value, or `null`.
  final num? max;

  /// Increment used by a numeric editor, or `null`.
  final num? step;

  /// Allowed values for [ParamValueType.enumeration], in display order.
  final List<String> allowed;

  /// Type of one element when the value is a list.
  final ParamValueType? itemType;

  /// Whether the flag can be repeated on the command line.
  final bool repeatable;

  /// Identifier of the [ParameterGroupSpec] this parameter belongs to.
  final String group;

  /// Surfaces where LlamaPulse can apply the parameter.
  final List<ParamSurface> surfaces;

  /// How LlamaPulse treats the parameter.
  final ParamExposure exposure;

  /// Field that stores the value, for example `contextSize` on
  /// `ServerConfig`, or `null` when no configuration field backs it.
  final String? owner;

  /// Component that owns the value when [exposure] is
  /// [ParamExposure.managed], for example `ServerConfig`.
  final String? managedBy;

  /// Environment variable that also sets the parameter, when upstream
  /// declares one.
  final String? envVar;

  /// Whether the parameter is meant for an advanced section of the UI.
  final bool advanced;

  /// Whether upstream marks the parameter as deprecated.
  final bool deprecated;

  /// Flag or parameter that replaces a [ParamExposure.removed] parameter.
  final String? replacement;

  /// Whether [type] is [ParamValueType.path] and the path must already exist.
  final bool requiresExistingPath;

  /// Safety or compatibility note shown next to the control.
  final String? warning;

  /// Why the parameter is [ParamExposure.unsupported] or
  /// [ParamExposure.removed], or why LlamaPulse manages it.
  final String? reason;

  /// Whether the parameter applies to [surface].
  bool appliesTo(ParamSurface surface) => surfaces.contains(surface);
}

/// Presentation group for parameters in the GUI and the CLI listing.
final class ParameterGroupSpec {
  /// Creates a group specification.
  const ParameterGroupSpec({
    required this.id,
    required this.name,
    required this.order,
    required this.defaultOpen,
  });

  /// Stable group identifier referenced by [ParameterSpec.group].
  final String id;

  /// Human-readable group name.
  final String name;

  /// Sort order; lower values come first.
  final int order;

  /// Whether the GUI opens this section by default.
  final bool defaultOpen;
}
