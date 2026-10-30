import 'package:flutter/material.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Inference workspace: startup parameters, generation output and metrics.
class InferenceScreen extends StatelessWidget {
  const InferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LlamaPulse'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: _StatusChip()),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Below 900 px a 380 px parameter column would leave too little
            // room for output, so the layout stacks instead.
            if (constraints.maxWidth >= 900) {
              return const _WideLayout();
            }
            return const _NarrowLayout();
          },
        ),
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 380,
            child: SingleChildScrollView(child: _ParametersCard()),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Expanded(flex: 3, child: _OutputCard()),
                SizedBox(height: 16),
                Expanded(flex: 2, child: _MetricsCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ParametersCard(),
          SizedBox(height: 16),
          _OutputCard(),
          SizedBox(height: 16),
          _MetricsCard(),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Idle',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _ParametersCard extends StatelessWidget {
  const _ParametersCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ModelParams params = ModelParams.defaults();
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
              'Defaults — not yet editable',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _ParameterRow(
              label: 'Model path',
              value: params.modelPath.isEmpty ? 'Not set' : params.modelPath,
            ),
            _ParameterRow(
              label: 'Context size',
              value: '${params.contextSize}',
            ),
            _ParameterRow(label: 'GPU layers', value: '${params.gpuLayers}'),
            _ParameterRow(label: 'Threads', value: '${params.threads}'),
            _ParameterRow(label: 'Temperature', value: '${params.temperature}'),
            _ParameterRow(label: 'Top-p', value: '${params.topP}'),
            _ParameterRow(label: 'Top-k', value: '${params.topK}'),
            _ParameterRow(label: 'Max tokens', value: '${params.maxTokens}'),
          ],
        ),
      ),
    );
  }
}

class _ParameterRow extends StatelessWidget {
  const _ParameterRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const ValueKey('output-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generation output', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: const _EmptyState(
                icon: Icons.notes_outlined,
                message: 'No output yet. Load a model to start generating.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const ValueKey('metrics-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metrics', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _EmptyState(
              icon: Icons.speed_outlined,
              message:
                  'Tokens per second and eval timings appear here after a '
                  'generation.',
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
