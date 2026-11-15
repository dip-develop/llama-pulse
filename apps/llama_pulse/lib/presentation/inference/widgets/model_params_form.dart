import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../app/platform/model_path_picker.dart';
import '../../../l10n/app_localizations.dart';
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
  late final TextEditingController _chatTemplateController;
  late final FocusNode _chatTemplateFocus;
  late final TextEditingController _systemPromptController;
  late final FocusNode _systemPromptFocus;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    final ModelParams params = widget.params;
    _modelPathController = TextEditingController(text: params.modelPath);
    _modelPathFocus = FocusNode();
    _chatTemplateController = TextEditingController(
      text: params.chatTemplate ?? '',
    );
    _chatTemplateFocus = FocusNode();
    _systemPromptController = TextEditingController(
      text: params.systemPrompt ?? '',
    );
    _systemPromptFocus = FocusNode();
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
      _chatTemplateController,
      _chatTemplateFocus,
      previous.chatTemplate ?? '',
      next.chatTemplate ?? '',
    );
    _sync(
      _systemPromptController,
      _systemPromptFocus,
      previous.systemPrompt ?? '',
      next.systemPrompt ?? '',
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
    _chatTemplateController.dispose();
    _chatTemplateFocus.dispose();
    _systemPromptController.dispose();
    _systemPromptFocus.dispose();
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Card(
      key: const ValueKey('parameters-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.chatModelParamsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.chatModelParamsHint,
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
                labelText: l10n.chatModelPath,
                hintText: l10n.modelPathExample,
                isDense: true,
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: TextButton(
                    key: const ValueKey('browse-model-path'),
                    onPressed: _browse,
                    child: Text(l10n.browseAction),
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
                    label: l10n.chatContextSize,
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
                    label: l10n.chatGpuLayers,
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
                    label: l10n.chatThreads,
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
                    label: l10n.chatTemperature,
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
                    label: l10n.chatTopP,
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
                    label: l10n.chatTopK,
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
              label: l10n.chatMaxTokens,
              keyboardType: TextInputType.number,
              onChanged: (String text) {
                final int? value = int.tryParse(text);
                if (value == null) {
                  return;
                }
                _dispatch(widget.params.copyWith(maxTokens: value));
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('chat-template'),
              controller: _chatTemplateController,
              focusNode: _chatTemplateFocus,
              decoration: InputDecoration(
                labelText: l10n.chatTemplateLabel,
                hintText: l10n.chatTemplateHint,
                isDense: true,
              ),
              onChanged: (String text) {
                final String trimmed = text.trim();
                _dispatch(
                  widget.params.copyWith(
                    chatTemplate: trimmed.isEmpty ? null : trimmed,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('system-prompt'),
              controller: _systemPromptController,
              focusNode: _systemPromptFocus,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.chatSystemPrompt,
                hintText: l10n.chatSystemPromptHint,
                isDense: true,
              ),
              onChanged: (String text) {
                _dispatch(
                  widget.params.copyWith(
                    systemPrompt: text.trim().isEmpty ? null : text,
                  ),
                );
              },
            ),
            SwitchListTile(
              key: const ValueKey('use-chat-template'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.chatApplyTemplate),
              subtitle: Text(l10n.chatApplyTemplateSubtitle),
              value: widget.params.useChatTemplate ?? true,
              onChanged: (bool value) =>
                  _dispatch(widget.params.copyWith(useChatTemplate: value)),
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
                  child: Text(l10n.saveAction),
                ),
                OutlinedButton(
                  key: const ValueKey('load-model'),
                  onPressed: _busy
                      ? null
                      : () => context.read<InferenceBloc>().add(
                          const InferenceLoadRequested(),
                        ),
                  child: Text(l10n.chatLoadModel),
                ),
                TextButton(
                  key: const ValueKey('unload-model'),
                  onPressed: widget.status == InferenceStatus.modelReady
                      ? () => context.read<InferenceBloc>().add(
                          const InferenceUnloadRequested(),
                        )
                      : null,
                  child: Text(l10n.unloadAction),
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
