import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../l10n/app_localizations.dart';

/// Builds the tooltip message shown next to a parameter label.
///
/// The message is the compact documentation a user needs to decide whether to
/// touch a flag: its command-line spellings, what it does, the value shape, the
/// upstream default, the accepted range and the environment variable that also
/// sets it. Lines that do not apply are omitted, so the result never contains
/// empty labels.
///
/// The scaffolding around the catalog text is localized; the catalog itself
/// (summary, description, reason, warning and replacement) is upstream content
/// and stays verbatim.
String parameterTooltip(AppLocalizations l10n, ParameterSpec spec) {
  final lines = <String>[];
  if (spec.flags.isNotEmpty) {
    lines.add(spec.flags.join(', '));
  }
  final String? negated = spec.negatedFlag;
  if (negated != null && negated.isNotEmpty) {
    lines.add(l10n.paramTooltipNegated(negated));
  }
  if (spec.summary.isNotEmpty) {
    lines.add(spec.summary);
  }
  if (spec.description.isNotEmpty && spec.description != spec.summary) {
    lines.add(spec.description);
  }
  lines.add(l10n.paramTooltipType(_typeLabel(l10n, spec)));
  final String defaultValue = ParameterValueCodec.formatDefault(spec);
  lines.add(
    l10n.paramTooltipDefault(
      defaultValue.isEmpty ? l10n.paramTooltipDynamic : defaultValue,
    ),
  );
  final String? range = _rangeLabel(l10n, spec);
  if (range != null) {
    lines.add(l10n.paramTooltipRange(range));
  }
  final String? envVar = spec.envVar;
  if (envVar != null && envVar.isNotEmpty) {
    lines.add(l10n.paramTooltipEnvironment(envVar));
  }
  final String? warning = spec.warning;
  if (warning != null && warning.isNotEmpty) {
    lines.add(l10n.paramTooltipWarning(warning));
  }
  final String? reason = spec.reason;
  if (reason != null && reason.isNotEmpty) {
    lines.add(l10n.paramTooltipNote(reason));
  }
  final String? replacement = spec.replacement;
  if (replacement != null && replacement.isNotEmpty) {
    lines.add(l10n.paramTooltipReplacedBy(replacement));
  }
  return lines.join('\n');
}

String _typeLabel(AppLocalizations l10n, ParameterSpec spec) {
  if (spec.arity == 2) {
    return l10n.paramTypeTwoValues;
  }
  final String base = switch (spec.type) {
    ParamValueType.bool => l10n.paramTypeSwitch,
    ParamValueType.int => l10n.paramTypeInteger,
    ParamValueType.double => l10n.paramTypeNumber,
    ParamValueType.enumeration => l10n.paramTypeOneOf(spec.allowed.join(', ')),
    ParamValueType.path => l10n.paramTypePath,
    ParamValueType.string => l10n.paramTypeText,
  };
  if (spec.repeatable) {
    return l10n.paramTypeOnePerLine(base);
  }
  if (spec.itemType != null) {
    return l10n.paramTypeCommaSeparated(base);
  }
  return base;
}

String? _rangeLabel(AppLocalizations l10n, ParameterSpec spec) {
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
    return l10n.paramRangeStep('$step');
  }
  if (step == null) {
    return bounds;
  }
  return l10n.paramRangeSteps(bounds, '$step');
}
