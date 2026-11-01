import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../app/platform/file_picker.dart';
import 'parameter_filter.dart';
import 'parameter_group_tile.dart';
import 'parameter_row.dart';

/// Grouped, searchable editor for the catalog values of one surface.
///
/// The panel is presentation-agnostic: it renders [params], the rows of
/// [editable] and the read-only containers of [lockedGroups], and reports edits
/// through [onChanged] and [onReset]. The server dashboard and the embedded
/// chat use the same widget with different catalogs and key prefixes. Rows
/// exist in the tree only while their group is open, and each row keeps its own
/// controller and focus node.
///
/// Expansion is local to this widget and never persisted. The catalog opens
/// the groups it marks `defaultOpen`, plus every group that holds a modified
/// value; a search expands the matching groups for as long as the query is not
/// empty and restores the stored expansion when it is cleared.
class ParameterPanel extends StatefulWidget {
  /// Creates the panel for [params].
  const ParameterPanel({
    super.key,
    required this.params,
    required this.filePicker,
    required this.editable,
    required this.lockedGroups,
    required this.valueForLocked,
    required this.onChanged,
    required this.onReset,
    this.title = 'Server parameters',
    this.subtitle =
        'Every other llama-server flag. The essentials stay in the form '
        'above and are saved with them.',
    this.keyPrefix = 'server-params',
    this.rowKeyPrefix = 'server-param',
  });

  /// Catalog values shown and edited by the panel.
  final BuiltMap<String, String> params;

  /// File dialog seam used by the Browse buttons of path parameters.
  final FilePicker filePicker;

  /// Rows the user edits in the panel, in catalog order.
  final List<ParameterSpec> editable;

  /// Read-only containers appended after the editable groups.
  final List<LockedParameterGroup> lockedGroups;

  /// Effective value shown under a locked row; return `null` for none.
  final String? Function(ParameterSpec spec) valueForLocked;

  /// Called with a canonical value, or `null` to remove the parameter.
  final void Function(String id, String? value) onChanged;

  /// Called with every id a group reset must remove.
  final void Function(Set<String> ids) onReset;

  /// Heading of the panel.
  final String title;

  /// One-line explanation rendered under [title].
  final String subtitle;

  /// Prefix of the panel-level keys, for example `server-params`.
  final String keyPrefix;

  /// Prefix of the row and group keys, for example `server-param`.
  final String rowKeyPrefix;

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
    _expanded.addAll(_defaultExpansion());
  }

  @override
  void didUpdateWidget(ParameterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.params == widget.params) {
      return;
    }
    // A value the user just modified in a still-closed group opens it once.
    // This runs during the parent's rebuild, so no extra frame is scheduled.
    for (final ParameterGroupView group in _groups()) {
      if (_decided.contains(group.spec.id)) {
        continue;
      }
      if (groupHasModification(group, widget.params)) {
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

  List<ParameterGroupView> _groups({
    String query = '',
    bool modifiedOnly = false,
  }) => parameterGroups(
    params: widget.params,
    query: query,
    modifiedOnly: modifiedOnly,
    editable: widget.editable,
    lockedGroups: widget.lockedGroups,
  );

  Set<String> _defaultExpansion() {
    final Set<String> expanded = {};
    for (final ParameterGroupView group in _groups()) {
      if (group.spec.defaultOpen ||
          groupHasModification(group, widget.params)) {
        expanded.add(group.spec.id);
        _decided.add(group.spec.id);
      }
    }
    return expanded;
  }

  int _modifiedCount() {
    var count = 0;
    for (final ParameterSpec spec in widget.editable) {
      if (isParameterModified(spec, widget.params[spec.id])) {
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
    final String? previous = widget.params[spec.id];
    widget.onChanged(spec.id, null);
    _showUndo({spec.id: previous}, 'Reset ${spec.displayName}');
  }

  void _resetGroup(ParameterGroupView group, List<String> ids) {
    final BuiltMap<String, String> params = widget.params;
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
    final List<ParameterGroupView> groups = _groups(
      query: _query,
      modifiedOnly: _modifiedOnly,
    );
    final int modified = _modifiedCount();
    final int available = widget.editable.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          widget.subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$modified modified / $available available',
          key: ValueKey('${widget.keyPrefix}-count'),
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          key: ValueKey('${widget.keyPrefix}-search'),
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
              key: ValueKey('${widget.keyPrefix}-modified-only'),
              value: _modifiedOnly,
              onChanged: (bool value) => setState(() => _modifiedOnly = value),
            ),
            IconButton(
              key: ValueKey('${widget.keyPrefix}-expand-all'),
              tooltip: 'Expand all',
              iconSize: 18,
              onPressed: () => _expandAll(groups),
              icon: const Icon(Icons.unfold_more),
            ),
            IconButton(
              key: ValueKey('${widget.keyPrefix}-collapse-all'),
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
              key: ValueKey('${widget.keyPrefix}-empty'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final ParameterGroupView group in groups) _buildGroup(group),
      ],
    );
  }

  Widget _buildGroup(ParameterGroupView group) {
    final BuiltMap<String, String> params = widget.params;
    final List<String> modifiedIds = group.locked
        ? const []
        : [
            for (final ParameterSpec spec in group.parameters)
              if (isParameterModified(spec, params[spec.id])) spec.id,
          ];
    return ParameterGroupTile(
      group: group,
      keyPrefix: widget.rowKeyPrefix,
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
            key: ValueKey('${widget.rowKeyPrefix}-row-${spec.id}'),
            keyPrefix: widget.rowKeyPrefix,
            spec: spec,
            value: _rowValue(group, spec),
            locked: group.locked,
            lockReason: group.locked ? _lockReason(group, spec) : null,
            filePicker: widget.filePicker,
            onChanged: (String? value) => widget.onChanged(spec.id, value),
            onReset: () => _resetRow(spec),
          ),
      ],
    );
  }

  String? _rowValue(ParameterGroupView group, ParameterSpec spec) {
    if (!group.locked) {
      return widget.params[spec.id];
    }
    if (!group.showValue) {
      return null;
    }
    return widget.valueForLocked(spec);
  }

  String? _lockReason(ParameterGroupView group, ParameterSpec spec) {
    final String? override = group.lockReason;
    if (override != null) {
      return override;
    }
    return switch (spec.exposure) {
      ParamExposure.managed =>
        spec.reason ?? 'Managed by ${spec.managedBy ?? 'LlamaPulse'}.',
      ParamExposure.unsupported =>
        spec.reason ?? 'llama-server does not accept this parameter.',
      ParamExposure.removed =>
        spec.reason ?? 'llama.cpp removed this parameter.',
      ParamExposure.configurable => null,
    };
  }
}
