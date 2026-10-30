import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../app/platform/model_path_picker.dart';
import '../bloc/inference_bloc.dart';
import '../bloc/inference_event.dart';
import '../bloc/inference_status.dart';

/// Editable startup parameters for the next model load.
///
/// Controllers are seeded from the state and refreshed only when the state
/// value actually changed and the field is not focused, so typing is never
/// interrupted by a rebuild.
class ModelParamsForm extends StatefulWidget {
  const ModelParamsForm({
    super.key,
    required this.status,
    required this.params,
    required this.picker,
  });

  /// Lifecycle status, used to enable the action buttons.
  final InferenceStatus status;

  /// Current parameters, including unsaved edits.
  final ModelParams params;

  /// File dialog seam used by the browse button.
  final ModelPathPicker picker;

  @override
  State<ModelParamsForm> createState() => _ModelParamsFormState();
}

class _ModelParamsFormState extends State<ModelParamsForm> {
  late final TextEditingController _modelPathController;
  late final FocusNode _modelPathFocus;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    final ModelParams params = widget.params;
    _modelPathController = TextEditingController(text: params.modelPath);
    _modelPathFocus = FocusNode();
    _controllers = {
      'context-size': TextEditingController(text: '${params.contextSize}'),
      'gpu-layers': TextEditingController(text: '${params.gpuLayers}'),
      'threads': TextEditingController(text: '${params.threads}'),
      'temperature': TextEditingController(text: '${params.temperature}'),
      'top-p': TextEditingController(text: '${params.topP}'),
      'top-k': TextEditingController(text: '${params.topK}'),
      'max-tokens': TextEditingController(text: '${params.maxTokens}'),
    };
    _focusNodes = {
      for (final String field in _controllers.keys) field: FocusNode(),
    };
  }

  @override
  void didUpdateWidget(ModelParamsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ModelParams previous = oldWidget.params;
    final ModelParams next = widget.params;
    _sync(
      _modelPathController,
      _modelPathFocus,
      previous.modelPath,
      next.modelPath,
    );
    _sync(
      _controllers['context-size']!,
      _focusNodes['context-size']!,
      '${previous.contextSize}',
      '${next.contextSize}',
    );
    _sync(
      _controllers['gpu-layers']!,
      _focusNodes['gpu-layers']!,
      '${previous.gpuLayers}',
      '${next.gpuLayers}',
    );
    _sync(
      _controllers['threads']!,
      _focusNodes['threads']!,
      '${previous.threads}',
      '${next.threads}',
    );
    _sync(
      _controllers['temperature']!,
      _focusNodes['temperature']!,
      '${previous.temperature}',
      '${next.temperature}',
    );
    _sync(
      _controllers['top-p']!,
      _focusNodes['top-p']!,
      '${previous.topP}',
      '${next.topP}',
    );
    _sync(
      _controllers['top-k']!,
      _focusNodes['top-k']!,
      '${previous.topK}',
      '${next.topK}',
    );
    _sync(
      _controllers['max-tokens']!,
      _focusNodes['max-tokens']!,
      '${previous.maxTokens}',
      '${next.maxTokens}',
    );
  }

  void _sync(
    TextEditingController controller,
    FocusNode focus,
    String previous,
    String next,
  ) {
    if (previous == next || focus.hasFocus || controller.text == next) {
      return;
    }
    controller.text = next;
  }

  @override
  void dispose() {
    _modelPathController.dispose();
    _modelPathFocus.dispose();
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    for (final FocusNode focus in _focusNodes.values) {
      focus.dispose();
    }
    super.dispose();
  }

  void _dispatch(ModelParams params) {
    context.read<InferenceBloc>().add(InferenceParamsChanged(params));
  }

  Future<void> _browse() async {
    final String? path = await widget.picker.pickGgufFile();
    if (!mounted || path == null) {
      return;
    }
    // The browse result is an explicit user action, so update the field even
    // if it still owns the focus.
    _modelPathController.text = path;
    _dispatch(widget.params.copyWith(modelPath: path));
  }

  bool get _busy =>
      widget.status == InferenceStatus.loadingModel ||
      widget.status == InferenceStatus.generating ||
      widget.status == InferenceStatus.cancelling;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const ValueKey('parameters-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Model parameters', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Changes apply to the next load.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('model-path'),
              controller: _modelPathController,
              focusNode: _modelPathFocus,
              decoration: InputDecoration(
                labelText: 'Model path',
                hintText: '/models/model.gguf',
                isDense: true,
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: TextButton(
                    key: const ValueKey('browse-model-path'),
                    onPressed: _browse,
                    child: const Text('Browse'),
                  ),
                ),
              ),
              onChanged: (String text) =>
                  _dispatch(widget.params.copyWith(modelPath: text)),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _numberField(
                    fieldKey: 'context-size',
                    label: 'Context size',
                    keyboardType: TextInputType.number,
                    onChanged: (String text) {
                      final int? value = int.tryParse(text);
                      if (value == null) {
                        return;
                      }
                      _dispatch(widget.params.copyWith(contextSize: value));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(
                    fieldKey: 'gpu-layers',
                    label: 'GPU layers',
                    keyboardType: TextInputType.number,
                    onChanged: (String text) {
                      final int? value = int.tryParse(text);
                      if (value == null) {
                        return;
                      }
                      _dispatch(widget.params.copyWith(gpuLayers: value));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _numberField(
                    fieldKey: 'threads',
                    label: 'Threads',
                    keyboardType: TextInputType.number,
                    onChanged: (String text) {
                      final int? value = int.tryParse(text);
                      if (value == null) {
                        return;
                      }
                      _dispatch(widget.params.copyWith(threads: value));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(
                    fieldKey: 'temperature',
                    label: 'Temperature',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (String text) {
                      final double? value = double.tryParse(text);
                      if (value == null) {
                        return;
                      }
                      _dispatch(widget.params.copyWith(temperature: value));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _numberField(
                    fieldKey: 'top-p',
                    label: 'Top-p',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (String text) {
                      final double? value = double.tryParse(text);
                      if (value == null) {
                        return;
                      }
                      _dispatch(widget.params.copyWith(topP: value));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(
                    fieldKey: 'top-k',
                    label: 'Top-k',
                    keyboardType: TextInputType.number,
                    onChanged: (String text) {
                      final int? value = int.tryParse(text);
                      if (value == null) {
                        return;
                      }
                      _dispatch(widget.params.copyWith(topK: value));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _numberField(
              fieldKey: 'max-tokens',
              label: 'Max tokens',
              keyboardType: TextInputType.number,
              onChanged: (String text) {
                final int? value = int.tryParse(text);
                if (value == null) {
                  return;
                }
                _dispatch(widget.params.copyWith(maxTokens: value));
              },
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const ValueKey('save-params'),
                  onPressed: _busy
                      ? null
                      : () => context.read<InferenceBloc>().add(
                          const InferenceSaveRequested(),
                        ),
                  child: const Text('Save'),
                ),
                OutlinedButton(
                  key: const ValueKey('load-model'),
                  onPressed: _busy
                      ? null
                      : () => context.read<InferenceBloc>().add(
                          const InferenceLoadRequested(),
                        ),
                  child: const Text('Load model'),
                ),
                TextButton(
                  key: const ValueKey('unload-model'),
                  onPressed: widget.status == InferenceStatus.modelReady
                      ? () => context.read<InferenceBloc>().add(
                          const InferenceUnloadRequested(),
                        )
                      : null,
                  child: const Text('Unload'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required String fieldKey,
    required String label,
    required TextInputType keyboardType,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      key: ValueKey(fieldKey),
      controller: _controllers[fieldKey],
      focusNode: _focusNodes[fieldKey],
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: onChanged,
    );
  }
}
