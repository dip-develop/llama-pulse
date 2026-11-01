import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Builds the tooltip message shown next to a parameter label.
///
/// The message is the compact documentation a user needs to decide whether to
/// touch a flag: its command-line spellings, what it does, the value shape, the
/// upstream default, the accepted range and the environment variable that also
/// sets it. Lines that do not apply are omitted, so the result never contains
/// empty labels.
String parameterTooltip(ParameterSpec spec) {
  final lines = <String>[];
  if (spec.flags.isNotEmpty) {
    lines.add(spec.flags.join(', '));
  }
  final String? negated = spec.negatedFlag;
  if (negated != null && negated.isNotEmpty) {
    lines.add('Negated form: $negated');
  }
  if (spec.summary.isNotEmpty) {
    lines.add(spec.summary);
  }
  if (spec.description.isNotEmpty && spec.description != spec.summary) {
    lines.add(spec.description);
  }
  lines.add('Type: ${_typeLabel(spec)}');
  final String defaultValue = ParameterValueCodec.formatDefault(spec);
  lines.add('Default: ${defaultValue.isEmpty ? 'dynamic' : defaultValue}');
  final String? range = _rangeLabel(spec);
  if (range != null) {
    lines.add('Range: $range');
  }
  final String? envVar = spec.envVar;
  if (envVar != null && envVar.isNotEmpty) {
    lines.add('Environment: $envVar');
  }
  final String? warning = spec.warning;
  if (warning != null && warning.isNotEmpty) {
    lines.add('Warning: $warning');
  }
  final String? reason = spec.reason;
  if (reason != null && reason.isNotEmpty) {
    lines.add('Note: $reason');
  }
  final String? replacement = spec.replacement;
  if (replacement != null && replacement.isNotEmpty) {
    lines.add('Replaced by: $replacement');
  }
  return lines.join('\n');
}

String _typeLabel(ParameterSpec spec) {
  if (spec.arity == 2) {
    return 'two values on separate lines';
  }
  final String base = switch (spec.type) {
    ParamValueType.bool => 'switch',
    ParamValueType.int => 'integer',
    ParamValueType.double => 'number',
    ParamValueType.enumeration => 'one of: ${spec.allowed.join(', ')}',
    ParamValueType.path => 'path',
    ParamValueType.string => 'text',
  };
  if (spec.repeatable) {
    return '$base, one per line';
  }
  if (spec.itemType != null) {
    return '$base, comma separated';
  }
  return base;
}

String? _rangeLabel(ParameterSpec spec) {
  final num? min = spec.min;
  final num? max = spec.max;
  final num? step = spec.step;
  final String? bounds = switch ((min, max)) {
    (final num low, final num high) => '$low..$high',
    (final num low, null) => '>= $low',
    (null, final num high) => '<= $high',
    _ => null,
  };
  if (bounds == null && step == null) {
    return null;
  }
  if (bounds == null) {
    return 'step $step';
  }
  if (step == null) {
    return bounds;
  }
  return '$bounds in steps of $step';
}
