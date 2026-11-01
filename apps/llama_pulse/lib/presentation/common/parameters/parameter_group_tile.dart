import 'package:flutter/material.dart';

import 'parameter_filter.dart';

/// One collapsible group of the parameter panel.
///
/// The header always renders, so the group order is stable when everything is
/// collapsed; the rows are built only while [expanded] is true, which keeps the
/// widget tree proportional to what the user sees. [onReset] is `null` for a
/// group without a modified value and for the locked containers.
class ParameterGroupTile extends StatelessWidget {
  /// Creates a group header around [children].
  const ParameterGroupTile({
    super.key,
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.modifiedCount = 0,
    this.onReset,
  });

  /// Group metadata and rows.
  final ParameterGroupView group;

  /// Whether the rows are part of the tree.
  final bool expanded;

  /// Called when the header is tapped.
  final VoidCallback onToggle;

  /// Rows rendered under the header while [expanded].
  final List<Widget> children;

  /// Number of rows whose value differs from the default.
  final int modifiedCount;

  /// Clears the modified values of this group; `null` when there are none.
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String id = group.spec.id;
    final String? resetKey = onReset == null
        ? null
        : 'server-param-group-$id-reset';
    return Column(
      key: ValueKey('server-param-group-$id'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey('server-param-group-$id-toggle'),
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    group.spec.name,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (group.locked)
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                if (modifiedCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '$modifiedCount',
                      key: ValueKey('server-param-group-$id-modified'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ),
                if (resetKey != null)
                  IconButton(
                    key: ValueKey(resetKey),
                    tooltip: 'Reset this group',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt),
                  ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Column(
              key: ValueKey('server-param-group-$id-rows'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
