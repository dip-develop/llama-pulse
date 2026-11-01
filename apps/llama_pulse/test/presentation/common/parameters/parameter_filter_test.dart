import 'package:built_collection/built_collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/presentation/common/parameters/parameter_filter.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

void main() {
  final ParameterCatalog catalog = ParameterCatalog.v080;

  BuiltMap<String, String> params([Map<String, String> values = const {}]) =>
      BuiltMap<String, String>(values);

  ParameterSpec spec(String id) {
    final ParameterSpec? found = catalog.byId(id);
    if (found == null) {
      throw StateError("the catalog has no parameter '$id'");
    }
    return found;
  }

  test('the editable set excludes owned and non-server parameters', () {
    final List<ParameterSpec> editable = editableServerParameters();
    expect(editable, hasLength(210));
    for (final ParameterSpec parameter in editable) {
      expect(parameter.exposure, ParamExposure.configurable);
      expect(parameter.owner, isNull);
      expect(parameter.appliesTo(ParamSurface.server), isTrue);
    }
    expect(
      editable.map((ParameterSpec parameter) => parameter.id),
      isNot(contains('ctx-size')),
      reason: 'a typed owner is edited in the essentials form',
    );
    expect(managedServerParameters(), hasLength(14));
    expect(unavailableParameters(), hasLength(138));
  });

  group('search', () {
    test('matches the id, the flags and the summary', () {
      final ParameterSpec temperature = spec('temp');
      expect(parameterMatchesQuery(temperature, 'temp'), isTrue);
      expect(parameterMatchesQuery(temperature, '--temperature'), isTrue);
      expect(
        parameterMatchesQuery(temperature, 'sampling temperature'),
        isTrue,
      );
      expect(
        parameterMatchesQuery(temperature, 'logit distribution'),
        isTrue,
        reason: 'the description is searched too',
      );
      expect(parameterMatchesQuery(temperature, 'top-k sampling'), isFalse);
    });

    test('is case-insensitive', () {
      final ParameterSpec topK = spec('top-k');
      expect(parameterMatchesQuery(topK, 'TOP-K'), isTrue);
      expect(parameterMatchesQuery(topK, 'Top-K Sampling Cutoff'), isTrue);
    });

    test('matches the group name the panel shows', () {
      final ParameterSpec contextSize = spec('ctx-size');
      expect(
        parameterMatchesQuery(
          contextSize,
          'managed by llamapulse',
          groupName: 'Managed by LlamaPulse',
        ),
        isTrue,
      );
      expect(
        parameterMatchesQuery(contextSize, 'managed by llamapulse'),
        isFalse,
        reason: 'the container title is only matched when supplied',
      );
      expect(
        parameterMatchesQuery(contextSize, 'model & context'),
        isTrue,
        reason: 'the catalog group name is always matched',
      );
    });

    test('an empty query matches everything', () {
      expect(parameterMatchesQuery(spec('help'), ''), isTrue);
      expect(parameterMatchesQuery(spec('help'), '   '), isTrue);
    });
  });

  test('a query expands the matching groups and clearing restores them', () {
    expect(
      isGroupExpanded(groupId: 'threads', query: 'cpu-mask', expanded: {}),
      isTrue,
    );
    expect(
      isGroupExpanded(groupId: 'memory', query: '', expanded: {'threads'}),
      isFalse,
    );
    expect(
      isGroupExpanded(groupId: 'threads', query: '  ', expanded: {'threads'}),
      isTrue,
    );
    expect(
      isGroupExpanded(groupId: 'threads', query: '', expanded: {'threads'}),
      isTrue,
    );
  });

  group('modified', () {
    test('an absent value is not a modification', () {
      expect(isParameterModified(spec('temp'), null), isFalse);
      expect(isParameterModified(spec('temp'), ''), isFalse);
    });

    test('compares against the default in canonical form', () {
      expect(isParameterModified(spec('temp'), '0.8'), isFalse);
      expect(isParameterModified(spec('temp'), '0.80'), isFalse);
      expect(isParameterModified(spec('temp'), '0.5'), isTrue);
      expect(isParameterModified(spec('cache-type-k'), 'f16'), isFalse);
      expect(isParameterModified(spec('cache-type-k'), 'q8_0'), isTrue);
    });

    test('any value differs from a dynamic default', () {
      expect(isParameterModified(spec('predict'), '128'), isTrue);
    });
  });

  test('groups keep catalog order and the containers come last', () {
    final List<ParameterGroupView> groups = parameterGroups(params: params());
    expect(groups.map((ParameterGroupView group) => group.spec.id), <String>[
      'essentials',
      'memory',
      'threads',
      'gpu',
      'batching',
      'sampling',
      'grammar',
      'lora',
      'server',
      'logging',
      'managed',
      'unsupported',
    ]);
    final ParameterGroupView managed = groups[groups.length - 2];
    expect(managed.spec.name, 'Managed by LlamaPulse');
    expect(managed.locked, isTrue);
    expect(
      managed.parameters.map((ParameterSpec parameter) => parameter.id),
      contains('ctx-size'),
    );
    final ParameterGroupView unavailable = groups.last;
    expect(unavailable.spec.name, 'Not available');
    expect(unavailable.locked, isTrue);
    expect(
      unavailable.parameters.map((ParameterSpec parameter) => parameter.id),
      contains('help'),
    );
  });

  test('a query keeps only the groups with a hit', () {
    final List<ParameterGroupView> groups = parameterGroups(
      params: params(),
      query: 'cpu-mask',
    );
    // The unsupported container matches too: one removed-ish flag mentions
    // the mask in its description, and the container is searchable as a row.
    expect(groups.map((ParameterGroupView group) => group.spec.id), <String>[
      'threads',
      'unsupported',
    ]);
    expect(
      groups.first.parameters.map((ParameterSpec parameter) => parameter.id),
      containsAll(<String>['cpu-mask', 'cpu-mask-batch']),
    );
    expect(
      groups.first.parameters.map((ParameterSpec parameter) => parameter.id),
      isNot(contains('pooling')),
    );
  });

  test('modified only keeps the edited rows and hides locked containers', () {
    final List<ParameterGroupView> groups = parameterGroups(
      params: params({'temp': '0.5', 'keep': '128'}),
      modifiedOnly: true,
    );
    expect(groups.map((ParameterGroupView group) => group.spec.id), <String>[
      'essentials',
      'sampling',
    ]);
    expect(
      groups
          .expand((ParameterGroupView group) => group.parameters)
          .map((ParameterSpec parameter) => parameter.id),
      <String>['keep', 'temp'],
    );
    expect(groups.any((ParameterGroupView group) => group.locked), isFalse);
  });

  test('an unmatched query and an empty modification set yield no group', () {
    expect(
      parameterGroups(params: params(), query: 'no-such-parameter'),
      isEmpty,
    );
    expect(parameterGroups(params: params(), modifiedOnly: true), isEmpty);
  });

  test('reports whether a group holds a modification', () {
    final List<ParameterGroupView> groups = parameterGroups(params: params());
    final ParameterGroupView sampling = groups.firstWhere(
      (ParameterGroupView group) => group.spec.id == 'sampling',
    );
    expect(groupHasModification(sampling, params()), isFalse);
    expect(groupHasModification(sampling, params({'temp': '0.5'})), isTrue);
    expect(groupHasModification(sampling, params({'temp': '0.8'})), isFalse);
  });
}
