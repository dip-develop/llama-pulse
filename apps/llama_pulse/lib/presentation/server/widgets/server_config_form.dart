import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../app/platform/model_path_picker.dart';
import '../../../app/platform/server_binary_picker.dart';
import '../bloc/server_bloc.dart';
import '../bloc/server_event.dart';

/// Editable launch configuration for the supervised server.
///
/// Controllers are seeded from [config] and only rewritten when the value
/// actually changed and the field is not focused, so a rebuild caused by a
/// metrics sample never fights the user's typing.
class ServerConfigForm extends StatefulWidget {
  const ServerConfigForm({
    super.key,
    required this.config,
    required this.dirty,
    required this.saving,
    required this.picker,
    required this.binaryPicker,
  });

  /// Configuration held by the bloc, including unsaved edits.
  final ServerConfig config;

  /// Whether the form holds changes that have not been persisted yet.
  final bool dirty;

  /// Whether a save is in flight.
  final bool saving;

  /// File dialog used by the model path browse button.
  final ModelPathPicker picker;

  /// File dialog used by the binary path browse button.
  final ServerBinaryPicker binaryPicker;

  @override
  State<ServerConfigForm> createState() => _ServerConfigFormState();
}

class _ServerConfigFormState extends State<ServerConfigForm> {
  late final TextEditingController _modelPathController;
  late final TextEditingController _binaryPathController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _contextSizeController;
  late final TextEditingController _threadsController;
  late final TextEditingController _gpuLayersController;
  late final TextEditingController _parallelSlotsController;
  late final TextEditingController _aliasController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _extraArgsController;
  late final TextEditingController _startupTimeoutController;

  late final Map<String, FocusNode> _focusNodes;

  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final ServerConfig config = widget.config;
    _modelPathController = TextEditingController(text: config.modelPath);
    _binaryPathController = TextEditingController(text: config.binaryPath);
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: '${config.port}');
    _contextSizeController = TextEditingController(
      text: '${config.contextSize}',
    );
    _threadsController = TextEditingController(text: '${config.threads}');
    _gpuLayersController = TextEditingController(text: '${config.gpuLayers}');
    _parallelSlotsController = TextEditingController(
      text: '${config.parallelSlots}',
    );
    _aliasController = TextEditingController(text: config.modelAlias);
    _apiKeyController = TextEditingController(text: config.apiKey);
    _extraArgsController = TextEditingController(
      text: config.extraArgs.join('\n'),
    );
    _startupTimeoutController = TextEditingController(
      text: '${config.startupTimeoutSeconds}',
    );
    _focusNodes = {for (final String field in _fieldKeys) field: FocusNode()};
  }

  static const List<String> _fieldKeys = [
    'server-model-path',
    'server-binary-path',
    'server-host',
    'server-port',
    'server-context-size',
    'server-threads',
    'server-gpu-layers',
    'server-parallel-slots',
    'server-alias',
    'server-api-key',
    'server-extra-args',
    'server-startup-timeout',
  ];

  @override
  void didUpdateWidget(ServerConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ServerConfig previous = oldWidget.config;
    final ServerConfig next = widget.config;
    // A save or a reload clears `dirty`: the stored values are authoritative
    // again, so the fields must follow even the ones the user still focuses.
    final bool force = oldWidget.dirty && !widget.dirty;
    _sync(
      _modelPathController,
      'server-model-path',
      previous.modelPath,
      next.modelPath,
      force: force,
    );
    _sync(
      _binaryPathController,
      'server-binary-path',
      previous.binaryPath,
      next.binaryPath,
      force: force,
    );
    _sync(
      _hostController,
      'server-host',
      previous.host,
      next.host,
      force: force,
    );
    _sync(
      _portController,
      'server-port',
      '${previous.port}',
      '${next.port}',
      force: force,
    );
    _sync(
      _contextSizeController,
      'server-context-size',
      '${previous.contextSize}',
      '${next.contextSize}',
      force: force,
    );
    _sync(
      _threadsController,
      'server-threads',
      '${previous.threads}',
      '${next.threads}',
      force: force,
    );
    _sync(
      _gpuLayersController,
      'server-gpu-layers',
      '${previous.gpuLayers}',
      '${next.gpuLayers}',
      force: force,
    );
    _sync(
      _parallelSlotsController,
      'server-parallel-slots',
      '${previous.parallelSlots}',
      '${next.parallelSlots}',
      force: force,
    );
    _sync(
      _aliasController,
      'server-alias',
      previous.modelAlias,
      next.modelAlias,
      force: force,
    );
    _sync(
      _apiKeyController,
      'server-api-key',
      previous.apiKey,
      next.apiKey,
      force: force,
    );
    _sync(
      _extraArgsController,
      'server-extra-args',
      previous.extraArgs.join('\n'),
      next.extraArgs.join('\n'),
      force: force,
    );
    _sync(
      _startupTimeoutController,
      'server-startup-timeout',
      '${previous.startupTimeoutSeconds}',
      '${next.startupTimeoutSeconds}',
      force: force,
    );
  }

  void _sync(
    TextEditingController controller,
    String field,
    String previous,
    String next, {
    required bool force,
  }) {
    if (controller.text == next) {
      return;
    }
    if (!force && (previous == next || _focusNodes[field]!.hasFocus)) {
      return;
    }
    controller.text = next;
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    for (final FocusNode focus in _focusNodes.values) {
      focus.dispose();
    }
    super.dispose();
  }

  Iterable<TextEditingController> get _controllers => [
    _modelPathController,
    _binaryPathController,
    _hostController,
    _portController,
    _contextSizeController,
    _threadsController,
    _gpuLayersController,
    _parallelSlotsController,
    _aliasController,
    _apiKeyController,
    _extraArgsController,
    _startupTimeoutController,
  ];

  void _dispatch(ServerConfig config) {
    context.read<ServerBloc>().add(ServerConfigChanged(config));
  }

  Future<void> _browseModel() async {
    final String? path = await widget.picker.pickGgufFile();
    if (!mounted || path == null) {
      return;
    }
    // An explicit pick wins over the focus guard, like the chat form's.
    _modelPathController.text = path;
    _dispatch(widget.config.copyWith(modelPath: path));
  }

  Future<void> _browseBinary() async {
    final String? path = await widget.binaryPicker.pickExecutable();
    if (!mounted || path == null) {
      return;
    }
    _binaryPathController.text = path;
    _dispatch(widget.config.copyWith(binaryPath: path));
  }

  void _applyInt(
    String text,
    ServerConfig Function(ServerConfig config, int value) apply,
  ) {
    final int? value = int.tryParse(text);
    if (value == null) {
      return;
    }
    _dispatch(apply(widget.config, value));
  }

  void _applyExtraArgs(String text) {
    final BuiltList<String> args = BuiltList<String>([
      for (final String line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ]);
    _dispatch(widget.config.copyWith(extraArgs: args));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const ValueKey('server-config-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Server configuration',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (widget.dirty)
                  Text(
                    'Unsaved changes',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Changes apply on the next start.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _pathField(
              fieldKey: 'server-model-path',
              controller: _modelPathController,
              label: 'Model path',
              hint: '/models/model.gguf',
              browseKey: 'server-model-browse',
              onBrowse: _browseModel,
              onChanged: (String text) =>
                  _dispatch(widget.config.copyWith(modelPath: text)),
            ),
            const SizedBox(height: 12),
            _pathField(
              fieldKey: 'server-binary-path',
              controller: _binaryPathController,
              label: 'llama-server binary',
              hint: 'auto-detected when empty',
              browseKey: 'server-binary-browse',
              onBrowse: _browseBinary,
              onChanged: (String text) =>
                  _dispatch(widget.config.copyWith(binaryPath: text)),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    fieldKey: 'server-host',
                    controller: _hostController,
                    label: 'Host',
                    onChanged: (String text) =>
                        _dispatch(widget.config.copyWith(host: text)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    fieldKey: 'server-port',
                    controller: _portController,
                    label: 'Port',
                    keyboardType: TextInputType.number,
                    onChanged: (String text) => _applyInt(
                      text,
                      (ServerConfig config, int value) =>
                          config.copyWith(port: value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    fieldKey: 'server-context-size',
                    controller: _contextSizeController,
                    label: 'Context size',
                    keyboardType: TextInputType.number,
                    onChanged: (String text) => _applyInt(
                      text,
                      (ServerConfig config, int value) =>
                          config.copyWith(contextSize: value),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    fieldKey: 'server-threads',
                    controller: _threadsController,
                    label: 'Threads',
                    keyboardType: TextInputType.number,
                    onChanged: (String text) => _applyInt(
                      text,
                      (ServerConfig config, int value) =>
                          config.copyWith(threads: value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    fieldKey: 'server-gpu-layers',
                    controller: _gpuLayersController,
                    label: 'GPU layers',
                    keyboardType: TextInputType.number,
                    onChanged: (String text) => _applyInt(
                      text,
                      (ServerConfig config, int value) =>
                          config.copyWith(gpuLayers: value),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    fieldKey: 'server-parallel-slots',
                    controller: _parallelSlotsController,
                    label: 'Parallel slots',
                    keyboardType: TextInputType.number,
                    onChanged: (String text) => _applyInt(
                      text,
                      (ServerConfig config, int value) =>
                          config.copyWith(parallelSlots: value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field(
              fieldKey: 'server-alias',
              controller: _aliasController,
              label: 'Model alias',
              onChanged: (String text) =>
                  _dispatch(widget.config.copyWith(modelAlias: text)),
            ),
            const SizedBox(height: 12),
            _field(
              fieldKey: 'server-api-key',
              controller: _apiKeyController,
              label: 'API key',
              hint: 'empty disables authentication',
              obscureText: _obscureApiKey,
              onChanged: (String text) =>
                  _dispatch(widget.config.copyWith(apiKey: text)),
              suffix: IconButton(
                key: const ValueKey('server-api-key-reveal'),
                tooltip: _obscureApiKey ? 'Reveal' : 'Hide',
                icon: Icon(
                  _obscureApiKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureApiKey = !_obscureApiKey),
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: const ValueKey('server-flash-attn'),
              child: DropdownButtonFormField<ServerFlashAttention>(
                // Rebuild the form field when the value changes, so a Reload
                // or a save that replaced the config shows the stored mode;
                // `initialValue` is only applied when the state is created.
                key: ValueKey(widget.config.flashAttention),
                initialValue: widget.config.flashAttention,
                decoration: const InputDecoration(
                  labelText: 'Flash attention',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: ServerFlashAttention.auto,
                    child: Text('auto'),
                  ),
                  DropdownMenuItem(
                    value: ServerFlashAttention.on,
                    child: Text('on'),
                  ),
                  DropdownMenuItem(
                    value: ServerFlashAttention.off,
                    child: Text('off'),
                  ),
                ],
                onChanged: (ServerFlashAttention? mode) {
                  if (mode == null) {
                    return;
                  }
                  _dispatch(widget.config.copyWith(flashAttention: mode));
                },
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              key: const ValueKey('server-mlock'),
              contentPadding: EdgeInsets.zero,
              title: const Text('mlock'),
              subtitle: const Text('Lock the model in RAM'),
              value: widget.config.mlock,
              onChanged: (bool value) =>
                  _dispatch(widget.config.copyWith(mlock: value)),
            ),
            SwitchListTile(
              key: const ValueKey('server-mmap'),
              contentPadding: EdgeInsets.zero,
              title: const Text('mmap'),
              subtitle: const Text('Memory-map the model file'),
              value: widget.config.mmap,
              onChanged: (bool value) =>
                  _dispatch(widget.config.copyWith(mmap: value)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('server-extra-args'),
              controller: _extraArgsController,
              focusNode: _focusNodes['server-extra-args'],
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Extra arguments',
                hintText: 'one argument per line',
                alignLabelWithHint: true,
                isDense: true,
              ),
              onChanged: _applyExtraArgs,
            ),
            const SizedBox(height: 12),
            _field(
              fieldKey: 'server-startup-timeout',
              controller: _startupTimeoutController,
              label: 'Startup timeout (s)',
              keyboardType: TextInputType.number,
              onChanged: (String text) => _applyInt(
                text,
                (ServerConfig config, int value) =>
                    config.copyWith(startupTimeoutSeconds: value),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const ValueKey('server-save'),
                  onPressed: widget.saving
                      ? null
                      : () => context.read<ServerBloc>().add(
                          const ServerSaveRequested(),
                        ),
                  child: const Text('Save'),
                ),
                OutlinedButton(
                  key: const ValueKey('server-reload'),
                  onPressed: () => context.read<ServerBloc>().add(
                    const ServerReloadRequested(),
                  ),
                  child: const Text('Reload'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String fieldKey,
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    String? hint,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextFormField(
      key: ValueKey(fieldKey),
      controller: controller,
      focusNode: _focusNodes[fieldKey],
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        suffixIcon: suffix,
      ),
      onChanged: onChanged,
    );
  }

  Widget _pathField({
    required String fieldKey,
    required TextEditingController controller,
    required String label,
    required String hint,
    required String browseKey,
    required VoidCallback onBrowse,
    required ValueChanged<String> onChanged,
  }) {
    return _field(
      fieldKey: fieldKey,
      controller: controller,
      label: label,
      hint: hint,
      onChanged: onChanged,
      suffix: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: TextButton(
          key: ValueKey(browseKey),
          onPressed: onBrowse,
          child: const Text('Browse'),
        ),
      ),
    );
  }
}
