import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/inference_bloc.dart';
import '../bloc/inference_state.dart';
import '../bloc/inference_status.dart';

/// Small pill in the app bar showing the current inference lifecycle.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<InferenceBloc, InferenceState, InferenceStatus>(
      selector: (InferenceState state) => state.status,
      builder: (BuildContext context, InferenceStatus status) {
        final ThemeData theme = Theme.of(context);
        final _ChipAppearance appearance = _appearance(
          status,
          theme.colorScheme,
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: appearance.background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            appearance.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: appearance.foreground,
            ),
          ),
        );
      },
    );
  }

  _ChipAppearance _appearance(InferenceStatus status, ColorScheme scheme) {
    if (status == InferenceStatus.loadingModel) {
      return _ChipAppearance(
        'Loading model',
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      );
    }
    if (status == InferenceStatus.modelReady) {
      return _ChipAppearance(
        'Ready',
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      );
    }
    if (status == InferenceStatus.generating) {
      return _ChipAppearance(
        'Generating',
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      );
    }
    if (status == InferenceStatus.cancelling) {
      return _ChipAppearance(
        'Cancelling',
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      );
    }
    if (status == InferenceStatus.failure) {
      return _ChipAppearance(
        'Error',
        scheme.errorContainer,
        scheme.onErrorContainer,
      );
    }
    return _ChipAppearance(
      'Idle',
      scheme.surfaceContainerHighest,
      scheme.onSurfaceVariant,
    );
  }
}

class _ChipAppearance {
  const _ChipAppearance(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;
}
