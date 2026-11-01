import 'package:built_collection/built_collection.dart';

import '../entities/parameter_spec.dart';
import 'parameter_catalog.dart';
import 'parameter_value_codec.dart';

/// Validates catalog values before they are stored or applied.
final class ParameterValidator {
  /// Creates a validator.
  ///
  /// [pathExists] is used only for parameters that require an existing path
  /// when validation runs for a start; the domain layer does not touch the
  /// filesystem itself.
  const ParameterValidator({this.pathExists});

  /// Optional filesystem predicate for `requiresExistingPath` parameters.
  final bool Function(String path)? pathExists;

  /// Returns one message per problem with [values].
  ///
  /// Known ids are reported in catalog order and unknown ids last, sorted.
  List<String> validateValues(
    BuiltMap<String, String> values, {
    required ParamSurface surface,
    required bool forStart,
  }) {
    final catalog = ParameterCatalog.v080;
    final messages = <String>[];
    final knownIds = {for (final spec in catalog.parameters) spec.id};

    for (final spec in catalog.parameters) {
      final value = values[spec.id];
      if (value == null) {
        continue;
      }
      final message = _validateOne(spec, surface);
      if (message != null) {
        messages.add(message);
      } else {
        messages.addAll(
          ParameterValueCodec.validate(
            spec,
            value,
            forStart: forStart,
            pathExists: pathExists,
          ),
        );
      }
    }

    final unknown = [
      for (final id in values.keys)
        if (!knownIds.contains(id)) id,
    ]..sort();
    for (final id in unknown) {
      messages.add("unknown parameter '$id' (run `llamapulse params catalog`)");
    }
    return messages;
  }

  String? _validateOne(ParameterSpec spec, ParamSurface surface) {
    switch (spec.exposure) {
      case ParamExposure.managed:
        return "'${spec.id}' is managed by ${_owner(spec)}";
      case ParamExposure.unsupported:
        return _unsupported(spec);
      case ParamExposure.removed:
        return _removed(spec);
      case ParamExposure.configurable:
        break;
    }
    if (!spec.appliesTo(surface)) {
      return "'${spec.id}' is not available for ${surface.wireName}";
    }
    return null;
  }

  static String _owner(ParameterSpec spec) =>
      spec.managedBy ?? spec.owner ?? 'LlamaPulse';

  static String _unsupported(ParameterSpec spec) {
    final reason = spec.reason;
    if (reason == null || reason.isEmpty) {
      return "'${spec.id}' is not supported";
    }
    return "'${spec.id}' is not supported: $reason";
  }

  static String _removed(ParameterSpec spec) {
    final replacement = spec.replacement;
    if (replacement != null && replacement.isNotEmpty) {
      return "'${spec.id}' was removed; use $replacement instead";
    }
    final reason = spec.reason;
    if (reason == null || reason.isEmpty) {
      return "'${spec.id}' was removed";
    }
    return "'${spec.id}' was removed: $reason";
  }
}
