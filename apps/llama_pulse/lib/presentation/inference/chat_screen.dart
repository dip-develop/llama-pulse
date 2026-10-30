import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../app/platform/model_path_picker.dart';
import 'bloc/inference_bloc.dart';
import 'bloc/inference_state.dart';
import 'bloc/inference_status.dart';
import 'widgets/failure_banner.dart';
import 'widgets/generation_controls.dart';
import 'widgets/generation_output.dart';
import 'widgets/metrics_panel.dart';
import 'widgets/model_params_form.dart';
import 'widgets/status_chip.dart';

/// Embedded chat workspace: startup parameters, generation output and metrics.
///
/// It renders inside the application shell, so it owns no [Scaffold] and no
/// [AppBar]: the shell provides those and keeps both tabs alive.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.picker, this.demoEngine = false});

  /// File dialog seam handed to the parameter form.
  final ModelPathPicker picker;

  /// Whether output comes from the synthetic stub engine.
  final bool demoEngine;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (demoEngine) const _DemoEngineBanner(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(alignment: Alignment.centerLeft, child: StatusChip()),
          ),
          const FailureBanner(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _PromptSection(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Below 900 px a 380 px parameter column would leave too
                // little room for output, so the layout stacks instead.
                if (constraints.maxWidth >= 900) {
                  return _WideLayout(picker: picker);
                }
                return _NarrowLayout(picker: picker);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoEngineBanner extends StatelessWidget {
  const _DemoEngineBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: const ValueKey('demo-engine-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.tertiaryContainer,
      child: Text(
        'Demo engine — output is synthetic.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}

class _PromptSection extends StatelessWidget {
  const _PromptSection();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      InferenceBloc,
      InferenceState,
      (InferenceStatus, String)
    >(
      selector: (InferenceState state) => (state.status, state.prompt),
      builder: (BuildContext context, (InferenceStatus, String) data) {
        final (InferenceStatus status, String prompt) = data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PromptEditor(),
            const SizedBox(height: 8),
            GenerationControls(status: status, prompt: prompt),
          ],
        );
      },
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.picker});

  final ModelPathPicker picker;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: _ParametersSection(picker: picker),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              children: [
                Expanded(flex: 3, child: GenerationOutput()),
                SizedBox(height: 16),
                Expanded(flex: 2, child: MetricsPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.picker});

  final ModelPathPicker picker;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ParametersSection(picker: picker),
          const SizedBox(height: 16),
          const SizedBox(height: 320, child: GenerationOutput()),
          const SizedBox(height: 16),
          const SizedBox(height: 260, child: MetricsPanel()),
        ],
      ),
    );
  }
}

class _ParametersSection extends StatelessWidget {
  const _ParametersSection({required this.picker});

  final ModelPathPicker picker;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      InferenceBloc,
      InferenceState,
      (InferenceStatus, ModelParams)
    >(
      selector: (InferenceState state) => (state.status, state.params),
      builder: (BuildContext context, (InferenceStatus, ModelParams) data) {
        final (InferenceStatus status, ModelParams params) = data;
        return ModelParamsForm(status: status, params: params, picker: picker);
      },
    );
  }
}
