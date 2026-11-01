import 'package:flutter/material.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../app/platform/file_picker.dart';
import 'parameter_control.dart';
import 'parameter_tooltip.dart';

/// One catalog parameter in the panel: label, help, control and reset.
///
/// The row owns its text controller, focus node and local validation error, so
/// typing in one row never touches another. A value is dispatched only once it
/// passes [ParameterValueCodec.validate]; invalid text stays local and is shown
/// under the field. Locked rows have no control: they explain why the parameter
/// cannot be edited and, for a managed value, what LlamaPulse passes instead.
class ParameterRow extends StatefulWidget {
  /// Creates a row for [spec].
  const ParameterRow({
    super.key,
    required this.spec,
    required this.value,
    required this.filePicker,
    required this.onChanged,
    required this.onReset,
    this.locked = false,
    this.lockReason,
    this.keyPrefix = 'server-param',
  });

  /// Parameter this row edits or explains.
  final ParameterSpec spec;

  /// Prefix of every key this row exposes.
  final String keyPrefix;

  /// Stored value of an editable row, effective value of a managed one.
  final String? value;

  /// File dialog seam used by the Browse button of a path parameter.
  final FilePicker filePicker;

  /// Called with the canonical value, or `null` to remove the parameter.
  final ValueChanged<String?> onChanged;

  /// Called when the user asks to clear the stored value.
  final VoidCallback onReset;

  /// Whether the row is read-only.
  final bool locked;

  /// Why the row is locked; defaults to [ParameterSpec.reason].
  final String? lockReason;

  @override
  State<ParameterRow> createState() => _ParameterRowState();
}

class _ParameterRowState extends State<ParameterRow> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  String? _error;

  bool get _isTextField =>
      widget.spec.type != ParamValueType.bool &&
      widget.spec.type != ParamValueType.enumeration;

  bool get _canReset => widget.value != null && widget.value!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(ParameterRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) {
      return;
    }
    // A value that changed under the user (undo, reset, reload) supersedes the
    // local complaint about what they had typed.
    _error = null;
    if (!_isTextField || _focus.hasFocus) {
      return;
    }
    _controller.text = widget.value ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply(String raw) {
    // Clearing a field removes the value: llama.cpp then applies its own
    // default. Every type allows it, including the numeric ones whose empty
    // string `validate` rejects.
    if (raw.isEmpty) {
      setState(() => _error = null);
      widget.onChanged(null);
      return;
    }
    final List<String> problems = ParameterValueCodec.validate(
      widget.spec,
      raw,
      forStart: false,
    );
    if (problems.isNotEmpty) {
      setState(() => _error = problems.first);
      return;
    }
    final String? canonical = ParameterValueCodec.parse(widget.spec, raw);
    setState(() => _error = null);
    widget.onChanged(canonical);
  }

  void _reset() {
    setState(() {
      _error = null;
      _controller.text = '';
    });
    widget.onReset();
  }

  Future<void> _browse() async {
    final String? path = await widget.filePicker.pickFile(
      dialogTitle: 'Select ${widget.spec.displayName}',
    );
    if (!mounted || path == null) {
      return;
    }
    final String current = _controller.text.trimRight();
    final String next = widget.spec.repeatable && current.isNotEmpty
        ? '$current\n$path'
        : path;
    _controller.text = next;
    _focus.requestFocus();
    _apply(next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String prefix = '${widget.keyPrefix}-${widget.spec.id}';
    return Padding(
      key: ValueKey(prefix),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        widget.spec.displayName,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      key: ValueKey('$prefix-tooltip'),
                      message: parameterTooltip(widget.spec),
                      waitDuration: const Duration(milliseconds: 400),
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.locked)
                Icon(
                  Icons.lock_outline,
                  key: ValueKey('$prefix-locked'),
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              else
                IconButton(
                  key: ValueKey('$prefix-reset'),
                  tooltip: 'Reset to default',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: _canReset ? _reset : null,
                  icon: const Icon(Icons.restart_alt),
                ),
            ],
          ),
          if (widget.locked)
            _lockedDetails(theme)
          else
            ParameterControl(
              spec: widget.spec,
              value: widget.value,
              controller: _controller,
              focusNode: _focus,
              error: _error,
              keyPrefix: prefix,
              onChanged: _apply,
              onBrowse: widget.spec.type == ParamValueType.path
                  ? _browse
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _lockedDetails(ThemeData theme) {
    final String reason = _reason();
    final String? value = _effectiveValue();
    final TextStyle? style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reason.isNotEmpty) Text(reason, style: style),
        if (value != null)
          Text(
            'Effective value: $value',
            key: ValueKey('${widget.keyPrefix}-${widget.spec.id}-effective'),
            style: style,
          ),
      ],
    );
  }

  String _reason() {
    final String reason = (widget.lockReason ?? widget.spec.reason ?? '')
        .trim();
    final String? replacement = widget.spec.replacement?.trim();
    final String hint = replacement == null || replacement.isEmpty
        ? ''
        : 'Use $replacement instead.';
    if (reason.isEmpty) {
      return hint;
    }
    if (hint.isEmpty) {
      return reason;
    }
    return '$reason $hint';
  }

  String? _effectiveValue() {
    final String? raw = widget.value;
    if (raw == null) {
      return null;
    }
    final String value = raw.trim();
    if (value.isEmpty) {
      return '—';
    }
    // The API key is a secret: the essentials form already hides it, so the
    // panel must not turn it into plain text.
    if (widget.spec.id == 'api-key') {
      return '••••••';
    }
    return value;
  }
}
