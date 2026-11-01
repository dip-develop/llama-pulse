import 'package:flutter/material.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Editable control for one catalog parameter.
///
/// The shape follows the catalog type: a switch for booleans, a dropdown for
/// enumerations and a text field for everything else, with the numeric
/// keyboards, the multiline layout for repeated and paired values, and the
/// Browse button of a path. The owning row keeps the controller and the focus
/// node, so only the edited row rebuilds while the user types.
class ParameterControl extends StatelessWidget {
  /// Creates the control for [spec].
  const ParameterControl({
    super.key,
    required this.spec,
    required this.value,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.keyPrefix,
    required this.onChanged,
    this.onBrowse,
  });

  /// Parameter the control edits.
  final ParameterSpec spec;

  /// Stored value, or `null` when the parameter is unset.
  final String? value;

  /// Controller of the text field; unused by the switch and the dropdown.
  final TextEditingController controller;

  /// Focus node of the text field; unused by the switch and the dropdown.
  final FocusNode focusNode;

  /// Validation message shown under the field, or `null` when it is valid.
  final String? error;

  /// Prefix of every key the control exposes.
  final String keyPrefix;

  /// Called with the raw input: `true`/`false`, the selected enum or the text.
  final ValueChanged<String> onChanged;

  /// Opens the file dialog for a path parameter; `null` for every other type.
  final Future<void> Function()? onBrowse;

  @override
  Widget build(BuildContext context) {
    return switch (spec.type) {
      ParamValueType.bool => _switch(),
      ParamValueType.enumeration => _dropdown(),
      _ => _field(),
    };
  }

  bool get _switchValue {
    final String? raw = value;
    if (raw == null || raw.isEmpty) {
      return spec.defaultValue == true;
    }
    try {
      return ParameterValueCodec.parse(spec, raw) == 'true';
    } on FormatException {
      return false;
    }
  }

  Widget _switch() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Switch(
        key: ValueKey('$keyPrefix-control'),
        value: _switchValue,
        onChanged: (bool next) => onChanged(next ? 'true' : 'false'),
      ),
    );
  }

  Widget _dropdown() {
    final String? current = value != null && spec.allowed.contains(value)
        ? value
        : null;
    return InputDecorator(
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      child: DropdownButton<String>(
        key: ValueKey('$keyPrefix-control'),
        value: current,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        hint: const Text('default'),
        items: [
          for (final String allowed in spec.allowed)
            DropdownMenuItem<String>(value: allowed, child: Text(allowed)),
        ],
        onChanged: (String? next) {
          if (next != null) {
            onChanged(next);
          }
        },
      ),
    );
  }

  Widget _field() {
    final bool multiline = spec.arity == 2 || spec.repeatable;
    return TextFormField(
      key: ValueKey('$keyPrefix-control'),
      controller: controller,
      focusNode: focusNode,
      keyboardType: _keyboardType,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 4 : 1,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        isDense: true,
        error: error == null
            ? null
            : Text(error!, key: ValueKey('$keyPrefix-error')),
        suffixIcon: onBrowse == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton(
                  key: ValueKey('$keyPrefix-browse'),
                  onPressed: onBrowse,
                  child: const Text('Browse'),
                ),
              ),
      ),
      onChanged: onChanged,
    );
  }

  TextInputType get _keyboardType => switch (spec.type) {
    ParamValueType.int => TextInputType.number,
    ParamValueType.double => const TextInputType.numberWithOptions(
      decimal: true,
    ),
    _ => TextInputType.text,
  };
}
