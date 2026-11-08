import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../bloc/inference_bloc.dart';
import '../bloc/inference_event.dart';
import '../bloc/inference_state.dart';
import '../bloc/inference_status.dart';

/// The conversation card: completed turns, the in-flight draft and a clear
/// action.
///
/// The selector deliberately reads only the transcript, the draft chunks and
/// the status, so a token or a metrics event never rebuilds the parameter
/// panels.
class ConversationView extends StatelessWidget {
  const ConversationView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const ValueKey('output-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child:
            BlocSelector<
              InferenceBloc,
              InferenceState,
              (BuiltList<ChatMessage>, BuiltList<String>, InferenceStatus)
            >(
              selector: (InferenceState state) =>
                  (state.transcript, state.outputChunks, state.status),
              builder:
                  (
                    BuildContext context,
                    (BuiltList<ChatMessage>, BuiltList<String>, InferenceStatus)
                    data,
                  ) {
                    final (
                      BuiltList<ChatMessage> transcript,
                      BuiltList<String> chunks,
                      InferenceStatus status,
                    ) = data;
                    final bool busy =
                        status == InferenceStatus.generating ||
                        status == InferenceStatus.cancelling;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Conversation',
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              key: const ValueKey('clear-conversation'),
                              onPressed: transcript.isEmpty || busy
                                  ? null
                                  : () => context.read<InferenceBloc>().add(
                                      const InferenceConversationCleared(),
                                    ),
                              child: const Text('Clear conversation'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: transcript.isEmpty && chunks.isEmpty
                              ? const _EmptyState(
                                  icon: Icons.forum_outlined,
                                  message: 'No messages yet.',
                                )
                              : _TranscriptList(
                                  transcript: transcript,
                                  draft: chunks.join(),
                                ),
                        ),
                      ],
                    );
                  },
            ),
      ),
    );
  }
}

/// Scrollable transcript with the in-flight draft appended as the last bubble.
///
/// It follows new content with `jumpTo`, rather than an animation, so a token
/// arriving mid-frame never leaves an animation running that a widget test
/// would have to settle. It only follows when the reader was already at the
/// bottom, and jumps once after the first layout so a fresh transcript starts
/// at its newest turn.
class _TranscriptList extends StatefulWidget {
  const _TranscriptList({required this.transcript, required this.draft});

  final BuiltList<ChatMessage> transcript;
  final String draft;

  @override
  State<_TranscriptList> createState() => _TranscriptListState();
}

class _TranscriptListState extends State<_TranscriptList> {
  /// How close to the bottom counts as "following along".
  static const double _followThreshold = 8;

  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToBottomAfterLayout();
  }

  @override
  void didUpdateWidget(covariant _TranscriptList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transcript.length != oldWidget.transcript.length ||
        widget.draft != oldWidget.draft) {
      if (_isNearBottom()) {
        _scrollToBottomAfterLayout();
      }
    }
  }

  /// Whether the current offset is close enough to the bottom to keep
  /// following, so a reader who scrolled up is not yanked back down.
  bool _isNearBottom() {
    if (!_controller.hasClients) {
      return true;
    }
    final ScrollPosition position = _controller.position;
    return position.maxScrollExtent - position.pixels <= _followThreshold;
  }

  void _scrollToBottomAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDraft = widget.draft.isNotEmpty;
    return ListView.builder(
      key: const ValueKey('chat-transcript'),
      controller: _controller,
      padding: EdgeInsets.zero,
      itemCount: widget.transcript.length + (hasDraft ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index < widget.transcript.length) {
          final ChatMessage message = widget.transcript[index];
          return _Bubble(
            key: ValueKey('transcript-turn-$index'),
            role: message.role,
            text: message.content,
            textKey: ValueKey('transcript-text-$index'),
          );
        }
        return _Bubble(
          role: ChatMessage.roleAssistant,
          text: widget.draft,
          textKey: const ValueKey('output-text'),
        );
      },
    );
  }
}

/// One rounded message bubble, right-aligned for the user, left otherwise.
class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.role,
    required this.text,
    required this.textKey,
  });

  final String role;
  final String text;
  final Key textKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isUser = role == ChatMessage.roleUser;
    final Color background = isUser
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final Color foreground = isUser
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _roleLabel(role),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: foreground.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                text,
                key: textKey,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _roleLabel(String role) => switch (role) {
    ChatMessage.roleUser => 'You',
    ChatMessage.roleAssistant => 'Assistant',
    ChatMessage.roleTool => 'Tool',
    _ => role,
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
