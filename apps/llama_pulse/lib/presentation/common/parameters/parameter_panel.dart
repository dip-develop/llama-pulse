import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../app/platform/file_picker.dart';
import 'parameter_filter.dart';
import 'parameter_group_tile.dart';
import 'parameter_row.dart';

/// Grouped, searchable editor for the catalog values of a server configuration.
///
/// The panel is presentation-agnostic: it renders [config] and reports edits
/// through [onChanged] and [onReset], so the same widget can back the
/// dashboard and, later, the embedded chat. Rows exist in the tree only while
/// their group is open, and each row keeps its own controller and focus node.
///
/// Expansion is local to this widget and never persisted. The catalog opens
/// the groups it marks `defaultOpen`, plus every group that holds a modified
/// value; a search expands the matching groups for as long as the query is not
/// empty and restores the stored expansion when it is cleared.
class ParameterPanel extends StatefulWidget {
  /// Creates the panel for [config].
  const ParameterPanel({
    super.key,
    required this.config,
    required this.filePicker,
    required this.onChanged,
    required this.onReset,
  });

  /// Configuration whose catalog values are shown and edited.
  final ServerConfig config;

  /// File dialog seam used by the Browse buttons of path parameters.
  final FilePicker filePicker;

  /// Called with a canonical value, or `null` to remove the parameter.
  final void Function(String id, String? value) onChanged;

  /// Called with every id a group reset must remove.
  final void Function(Set<String> ids) onReset;

  @override
  State<ParameterPanel> createState() => _ParameterPanelState();
}

class _ParameterPanelState extends State<ParameterPanel> {
  final TextEditingController _search = TextEditingController();

  /// Groups the user sees expanded, or that were expanded on their behalf.
  final Set<String> _expanded = {};

  /// Groups whose expansion was already decided once.
  ///
  /// A group the user collapsed must not pop open again when a value inside it
  /// changes, so a decision is never revisited.
  final Set<String> _decided = {};

  String _query = '';
  bool _modifiedOnly = false;

  @override
  void initState() {
    super.initState();
    _expanded.addAll(_defaultExpansion(widget.config.params));
  }

  @override
  void didUpdateWidget(ParameterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.params == widget.config.params) {
      return;
    }
    // A value the user just modified in a still-closed group opens it once.
    // This runs during the parent's rebuild, so no extra frame is scheduled.
    for (final ParameterGroupView group in parameterGroups(
      params: widget.config.params,
    )) {
      if (_decided.contains(group.spec.id)) {
        continue;
      }
      if (groupHasModification(group, widget.config.params)) {
        _decided.add(group.spec.id);
        _expanded.add(group.spec.id);
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Set<String> _defaultExpansion(BuiltMap<String, String> params) {
    final Set<String> expanded = {};
    for (final ParameterGroupView group in parameterGroups(params: params)) {
      if (group.spec.defaultOpen || groupHasModification(group, params)) {
        expanded.add(group.spec.id);
        _decided.add(group.spec.id);
      }
    }
    return expanded;
  }

  List<ParameterSpec> get _editable => editableServerParameters();

  int _modifiedCount(BuiltMap<String, String> params) {
    var count = 0;
    for (final ParameterSpec spec in _editable) {
      if (isParameterModified(spec, params[spec.id])) {
        count++;
      }
    }
    return count;
  }

  void _toggle(ParameterGroupView group) {
    setState(() {
      _decided.add(group.spec.id);
      if (!_expanded.remove(group.spec.id)) {
        _expanded.add(group.spec.id);
      }
    });
  }

  void _expandAll(List<ParameterGroupView> groups) {
    setState(() {
      for (final ParameterGroupView group in groups) {
        _expanded.add(group.spec.id);
        _decided.add(group.spec.id);
      }
    });
  }

  void _collapseAll(List<ParameterGroupView> groups) {
    setState(() {
      for (final ParameterGroupView group in groups) {
        _expanded.remove(group.spec.id);
        _decided.add(group.spec.id);
      }
    });
  }

  void _resetRow(ParameterSpec spec) {
    final String? previous = widget.config.params[spec.id];
    widget.onChanged(spec.id, null);
    _showUndo({spec.id: previous}, 'Reset ${spec.displayName}');
  }

  void _resetGroup(ParameterGroupView group, List<String> ids) {
    final BuiltMap<String, String> params = widget.config.params;
    final Map<String, String?> previous = {
      for (final String id in ids) id: params[id],
    };
    if (previous.isEmpty) {
      return;
    }
    widget.onReset(previous.keys.toSet());
    _showUndo(
      previous,
      previous.length == 1
          ? 'Reset 1 parameter in ${group.spec.name}'
          : 'Reset ${previous.length} parameters in ${group.spec.name}',
    );
  }

  void _showUndo(Map<String, String?> previous, String message) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              for (final MapEntry<String, String?> entry in previous.entries) {
                widget.onChanged(entry.key, entry.value);
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BuiltMap<String, String> params = widget.config.params;
    final List<ParameterGroupView> groups = parameterGroups(
      params: params,
      query: _query,
      modifiedOnly: _modifiedOnly,
    );
    final int modified = _modifiedCount(params);
    final int available = _editable.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Server parameters', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Every other llama-server flag. The essentials stay in the form '
          'above and are saved with them.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$modified modified / $available available',
          key: const ValueKey('server-params-count'),
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('server-params-search'),
          controller: _search,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'Search parameters',
          ),
          onChanged: (String text) => setState(() => _query = text),
        ),
        Row(
          children: [
            Expanded(
              child: Text('Modified only', style: theme.textTheme.bodySmall),
            ),
            Switch(
              key: const ValueKey('server-params-modified-only'),
              value: _modifiedOnly,
              onChanged: (bool value) => setState(() => _modifiedOnly = value),
            ),
            IconButton(
              key: const ValueKey('server-params-expand-all'),
              tooltip: 'Expand all',
              iconSize: 18,
              onPressed: () => _expandAll(groups),
              icon: const Icon(Icons.unfold_more),
            ),
            IconButton(
              key: const ValueKey('server-params-collapse-all'),
              tooltip: 'Collapse all',
              iconSize: 18,
              onPressed: () => _collapseAll(groups),
              icon: const Icon(Icons.unfold_less),
            ),
          ],
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No parameters match',
              key: const ValueKey('server-params-empty'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final ParameterGroupView group in groups)
            _buildGroup(group, params),
      ],
    );
  }

  Widget _buildGroup(
    ParameterGroupView group,
    BuiltMap<String, String> params,
  ) {
    final List<String> modifiedIds = group.locked
        ? const []
        : [
            for (final ParameterSpec spec in group.parameters)
              if (isParameterModified(spec, params[spec.id])) spec.id,
          ];
    return ParameterGroupTile(
      group: group,
      expanded: isGroupExpanded(
        groupId: group.spec.id,
        query: _query,
        expanded: _expanded,
      ),
      modifiedCount: modifiedIds.length,
      onToggle: () => _toggle(group),
      onReset: modifiedIds.isEmpty
          ? null
          : () => _resetGroup(group, modifiedIds),
      children: [
        for (final ParameterSpec spec in group.parameters)
          ParameterRow(
            key: ValueKey('parameter-row-${spec.id}'),
            spec: spec,
            value: _rowValue(group, spec),
            locked: group.locked,
            lockReason: group.locked ? _lockReason(spec) : null,
            filePicker: widget.filePicker,
            onChanged: (String? value) => widget.onChanged(spec.id, value),
            onReset: () => _resetRow(spec),
          ),
      ],
    );
  }

  String? _rowValue(ParameterGroupView group, ParameterSpec spec) {
    if (!group.locked) {
      return widget.config.params[spec.id];
    }
    if (spec.exposure != ParamExposure.managed) {
      return null;
    }
    return ParameterValues.valueFor(widget.config, spec.id);
  }

  String? _lockReason(ParameterSpec spec) => switch (spec.exposure) {
    ParamExposure.managed =>
      spec.reason ?? 'Managed by ${spec.managedBy ?? 'LlamaPulse'}.',
    ParamExposure.unsupported =>
      spec.reason ?? 'llama-server does not accept this parameter.',
    ParamExposure.removed => spec.reason ?? 'llama.cpp removed this parameter.',
    ParamExposure.configurable => null,
  };
}
