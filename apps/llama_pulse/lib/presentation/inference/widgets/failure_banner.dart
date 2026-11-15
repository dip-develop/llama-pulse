import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../l10n/app_localizations.dart';
import '../bloc/inference_bloc.dart';
import '../bloc/inference_state.dart';
import '../inference_failure_labels.dart';

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
        final AppLocalizations l10n = AppLocalizations.of(context)!;
        final String? details = failure.details;
        final String message = failure.message.trim();
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inferenceFailureLabel(l10n, failure.code),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      if (message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      if (details != null && details.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            details,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                    ],
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
