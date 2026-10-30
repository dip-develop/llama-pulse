import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/inference_bloc.dart';
import '../bloc/inference_state.dart';

/// Streaming text produced by the current or last generation.
class GenerationOutput extends StatelessWidget {
  const GenerationOutput({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const ValueKey('output-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generation output', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child:
                  BlocSelector<
                    InferenceBloc,
                    InferenceState,
                    BuiltList<String>
                  >(
                    selector: (InferenceState state) => state.outputChunks,
                    builder: (BuildContext context, BuiltList<String> chunks) {
                      if (chunks.isEmpty) {
                        return _EmptyState(
                          icon: Icons.notes_outlined,
                          message: 'No output yet.',
                        );
                      }
                      return SingleChildScrollView(
                        child: SelectableText(
                          chunks.join(),
                          key: const ValueKey('output-text'),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
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
