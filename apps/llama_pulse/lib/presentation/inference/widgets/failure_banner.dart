import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../bloc/inference_bloc.dart';
import '../bloc/inference_state.dart';

/// Error strip shown while the last action failed.
///
/// It never hides the generated output: a partial response stays readable
/// underneath so the user can copy it before retrying.
class FailureBanner extends StatelessWidget {
  const FailureBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<InferenceBloc, InferenceState, InferenceFailure?>(
      selector: (InferenceState state) => state.failure,
      builder: (BuildContext context, InferenceFailure? failure) {
        if (failure == null) {
          return const SizedBox.shrink();
        }
        final ThemeData theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            key: const ValueKey('failure-banner'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 20,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${failure.code.name}: ${failure.message}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
