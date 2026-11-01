import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Catalog id of the container group for parameters LlamaPulse owns.
const String managedParameterGroupId = 'managed';

/// Catalog id of the container group for parameters the server cannot take.
const String unavailableParameterGroupId = 'unsupported';

/// One group of rows as the parameter panel presents it.
///
/// [locked] is true for the read-only containers: the managed values come from
/// a typed field or from the supervisor, and unsupported or removed flags
/// cannot be passed at all. The panel renders their rows without a control.
final class ParameterGroupView {
  /// Creates a group view.
  const ParameterGroupView({
    required this.spec,
    required this.parameters,
    required this.locked,
    this.lockReason,
    this.showValue = true,
  });

  /// Group metadata: id, name, order and the default expansion.
  final ParameterGroupSpec spec;

  /// Rows of this group, in catalog order.
  final List<ParameterSpec> parameters;

  /// Whether every row of this group is read-only.
  final bool locked;

  /// Explanation shown for every locked row; `null` keeps the per-spec reason.
  final String? lockReason;

  /// Whether the panel prints the effective value of a locked row.
  final bool showValue;
}

/// A read-only container the panel appends after the editable groups.
///
/// The server surface uses the catalog's managed and unavailable groups; the
/// embedded chat uses its own containers for the values the essentials form
/// owns and for the flags the embedded engine cannot honour.
final class LockedParameterGroup {
  /// Creates a locked container.
  const LockedParameterGroup({
    required this.spec,
    required this.parameters,
    this.reason,
    this.showValue = true,
  });

  /// Group metadata: id, name, order and the default expansion.
  final ParameterGroupSpec spec;

  /// Rows of this group, in catalog order.
  final List<ParameterSpec> parameters;

  /// Explanation shown for every row; `null` keeps the per-spec reason.
  final String? reason;

  /// Whether the panel prints the effective value of a row.
  final bool showValue;
}

final List<ParameterSpec> _serverParameters = ParameterCatalog.v080.forSurface(
  ParamSurface.server,
);

final List<ParameterSpec> _editable = List<ParameterSpec>.unmodifiable([
  for (final spec in _serverParameters)
    if (spec.exposure == ParamExposure.configurable && spec.owner == null) spec,
]);

final List<ParameterSpec> _managed = List<ParameterSpec>.unmodifiable([
  for (final spec in _serverParameters)
    if (spec.exposure == ParamExposure.managed) spec,
]);

final List<ParameterSpec> _unavailable = List<ParameterSpec>.unmodifiable([
  for (final spec in ParameterCatalog.v080.parameters)
    if (spec.exposure == ParamExposure.unsupported ||
        spec.exposure == ParamExposure.removed)
      spec,
]);

final Map<String, ParameterGroupSpec> _groups = {
  for (final group in ParameterCatalog.v080.groups) group.id: group,
};

final Map<String, String> _groupNames = {
  for (final group in ParameterCatalog.v080.groups) group.id: group.name,
};

/// Every catalog parameter the panel lets the user edit.
///
/// Configurable on the server surface and without a typed owner: a value that
/// backs a field of the essentials form is edited there, not here.
List<ParameterSpec> editableServerParameters() => _editable;

/// Every catalog parameter LlamaPulse sets for the server itself.
List<ParameterSpec> managedServerParameters() => _managed;

/// Every catalog parameter the server cannot take any more.
///
/// Unsupported and removed flags carry no surface, so they are listed whole:
/// the group explains why the flag is missing instead of hiding it.
List<ParameterSpec> unavailableParameters() => _unavailable;

/// Whether [spec] matches [query].
///
/// Matching is case-insensitive and covers the canonical id, every flag token,
/// both display names, the summary, the description and the group name.
/// [groupName] is the container the panel shows the row under, so the managed
/// and unavailable containers are searchable by their own title as well.
bool parameterMatchesQuery(
  ParameterSpec spec,
  String query, {
  String? groupName,
}) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  final haystack = StringBuffer()
    ..write(spec.id)
    ..write('\n')
    ..write(spec.displayName)
    ..write('\n')
    ..write(spec.summary)
    ..write('\n')
    ..write(spec.description)
    ..write('\n')
    ..write(spec.flags.join('\n'))
    ..write('\n')
    ..write(spec.negatedFlag ?? '')
    ..write('\n')
    ..write(_groupNames[spec.group] ?? '');
  if (groupName != null) {
    haystack
      ..write('\n')
      ..write(groupName);
  }
  return haystack.toString().toLowerCase().contains(needle);
}

/// Whether [value] is a change away from the upstream default.
///
/// An absent value is not a modification: llama.cpp then applies its own
/// default, and every parameter would otherwise look edited. A present value
/// counts only when it differs from the catalog default in canonical form, so
/// `0.80` is not a change of a parameter whose default is `0.8`.
bool isParameterModified(ParameterSpec spec, String? value) =>
    !ParameterValueCodec.isDefault(spec, value);

/// Whether [group] holds a value the user changed away from the default.
bool groupHasModification(
  ParameterGroupView group,
  BuiltMap<String, String> params,
) =>
    !group.locked &&
    group.parameters.any(
      (ParameterSpec spec) => isParameterModified(spec, params[spec.id]),
    );

/// Whether the panel shows [groupId] as expanded.
///
/// A non-empty query always expands the matching groups so the hits are
/// visible; clearing it restores the expansion the widget stored.
bool isGroupExpanded({
  required String groupId,
  required String query,
  required Set<String> expanded,
}) => query.trim().isNotEmpty || expanded.contains(groupId);

/// The read-only containers of the server surface, in catalog order.
List<LockedParameterGroup> serverLockedParameterGroups() => _serverLockedGroups;

final List<LockedParameterGroup> _serverLockedGroups = List.unmodifiable([
  LockedParameterGroup(
    spec: _group(managedParameterGroupId),
    parameters: _managed,
  ),
  LockedParameterGroup(
    spec: _group(unavailableParameterGroupId),
    parameters: _unavailable,
    showValue: false,
  ),
]);

/// Builds the groups the panel shows for [params].
///
/// [editable] defaults to the server rows and [lockedGroups] to the server
/// containers. Configurable groups keep catalog order. The locked containers
/// are appended at their catalog position (orders 900 and 999) and are
/// read-only. Groups without a matching row are dropped, so an empty result is
/// the "no parameters match" state. Modified-only hides the locked containers:
/// they hold no user edits by definition.
List<ParameterGroupView> parameterGroups({
  required BuiltMap<String, String> params,
  String query = '',
  bool modifiedOnly = false,
  List<ParameterSpec>? editable,
  List<LockedParameterGroup>? lockedGroups,
}) {
  final List<ParameterSpec> editableRows =
      editable ?? editableServerParameters();
  final List<LockedParameterGroup> containers =
      lockedGroups ?? serverLockedParameterGroups();
  final Set<String> lockedIds = {
    for (final LockedParameterGroup group in containers) group.spec.id,
  };

  bool visible(ParameterSpec spec) =>
      (!modifiedOnly || isParameterModified(spec, params[spec.id])) &&
      parameterMatchesQuery(spec, query);

  final List<ParameterGroupSpec> groupSpecs =
      [
        for (final group in ParameterCatalog.v080.groups)
          if (!lockedIds.contains(group.id)) group,
        for (final LockedParameterGroup group in containers) group.spec,
      ]..sort(
        (ParameterGroupSpec a, ParameterGroupSpec b) =>
            a.order.compareTo(b.order),
      );

  final Map<String, LockedParameterGroup> lockedById = {
    for (final LockedParameterGroup group in containers) group.spec.id: group,
  };

  final List<ParameterGroupView> groups = [];
  for (final ParameterGroupSpec group in groupSpecs) {
    final LockedParameterGroup? locked = lockedById[group.id];
    if (locked != null) {
      if (modifiedOnly) {
        continue;
      }
      final List<ParameterSpec> rows = [
        for (final spec in locked.parameters)
          if (parameterMatchesQuery(spec, query, groupName: group.name)) spec,
      ];
      if (rows.isEmpty) {
        continue;
      }
      groups.add(
        ParameterGroupView(
          spec: group,
          parameters: rows,
          locked: true,
          lockReason: locked.reason,
          showValue: locked.showValue,
        ),
      );
      continue;
    }
    final List<ParameterSpec> rows = [
      for (final spec in editableRows)
        if (spec.group == group.id && visible(spec)) spec,
    ];
    if (rows.isNotEmpty) {
      groups.add(
        ParameterGroupView(spec: group, parameters: rows, locked: false),
      );
    }
  }
  return groups;
}

/// Returns the catalog group with [id].
ParameterGroupSpec _group(String id) {
  final group = _groups[id];
  if (group == null) {
    throw StateError("the catalog has no group '$id'");
  }
  return group;
}
