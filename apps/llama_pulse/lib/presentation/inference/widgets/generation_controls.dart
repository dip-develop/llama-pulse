import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../bloc/inference_bloc.dart';
import '../bloc/inference_event.dart';
import '../bloc/inference_state.dart';
import '../bloc/inference_status.dart';

/// Multi-line prompt editor bound to the bloc.
///
/// Like the parameter form, it only writes the text back when the state value
/// changed and the field does not own the focus.
class PromptEditor extends StatefulWidget {
  const PromptEditor({super.key});

  @override
  State<PromptEditor> createState() => _PromptEditorState();
}

class _PromptEditorState extends State<PromptEditor> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _seeded = true;
      _controller.text = context.read<InferenceBloc>().state.prompt;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return BlocListener<InferenceBloc, InferenceState>(
      listenWhen: (InferenceState previous, InferenceState current) =>
          previous.prompt != current.prompt,
      listener: (BuildContext context, InferenceState state) {
        if (!_focus.hasFocus && _controller.text != state.prompt) {
          _controller.text = state.prompt;
        }
      },
      child: TextField(
        key: const ValueKey('prompt-field'),
        controller: _controller,
        focusNode: _focus,
        minLines: 2,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: l10n.chatPromptLabel,
          hintText: l10n.chatPromptHint,
          alignLabelWithHint: true,
        ),
        onChanged: (String text) =>
            context.read<InferenceBloc>().add(InferencePromptChanged(text)),
      ),
    );
  }
}

/// Generate, cancel and unload actions for the current model.
class GenerationControls extends StatelessWidget {
  const GenerationControls({
    super.key,
    required this.status,
    required this.prompt,
  });

  /// Lifecycle status that decides which buttons are available.
  final InferenceStatus status;

  /// Current prompt text; generation needs a non-blank one.
  final String prompt;

  @override
  Widget build(BuildContext context) {
    final bool canGenerate =
        status == InferenceStatus.modelReady && prompt.trim().isNotEmpty;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          key: const ValueKey('generate'),
          onPressed: canGenerate
              ? () => context.read<InferenceBloc>().add(
                  const InferenceGenerateRequested(),
                )
              : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.chatGenerate),
        ),
        if (status == InferenceStatus.generating)
          OutlinedButton.icon(
            key: const ValueKey('cancel-generation'),
            onPressed: () => context.read<InferenceBloc>().add(
              const InferenceCancelRequested(),
            ),
            icon: const Icon(Icons.stop),
            label: Text(l10n.cancelAction),
          ),
        TextButton(
          key: const ValueKey('unload-generation'),
          onPressed: status == InferenceStatus.modelReady
              ? () => context.read<InferenceBloc>().add(
                  const InferenceUnloadRequested(),
                )
              : null,
          child: Text(l10n.unloadAction),
        ),
      ],
    );
  }
}
