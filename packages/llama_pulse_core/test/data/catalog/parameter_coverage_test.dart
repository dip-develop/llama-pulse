import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

import '../../support/catalog_files.dart';

/// Parameters the embedded native session can honour today.
///
/// `chat-template` is wired through `ModelParams.chatTemplate` into the native
/// session, so the catalog may claim the embedded surface for it.
const _embeddedHonoured = {
  'batch-size',
  'chat-template',
  'ctx-size',
  'gpu-layers',
  'min-p',
  'seed',
  'temp',
  'threads',
  'top-k',
  'top-p',
};

void main() {
  final files = CatalogFiles.instance;
  final overrides = files.readYaml(files.overrides);
  final parsed = parseUpstreamArgs(files.upstreamArgSource.readAsStringSync());
  final catalog = ParameterCatalog.v080;

  test('the vendored arg.cpp parses without gaps', () {
    expect(parsed.failures, isEmpty, reason: parsed.failures.join('\n'));
    expect(parsed.definitions, hasLength(greaterThan(300)));
  });

  test(
    'every server-visible flag is in the catalog or ignored with a reason',
    () {
      final ignored = _ignoredFlags(overrides);
      final catalogFlags = _catalogFlags(catalog);
      final missing = <String>[];
      for (final definition in parsed.definitions) {
        if (!definition.isVisibleToServer) {
          continue;
        }
        for (final flag in [...definition.flags, ...definition.negatedFlags]) {
          if (!catalogFlags.contains(flag) && !ignored.containsKey(flag)) {
            missing.add('$flag (arg.cpp:${definition.line})');
          }
        }
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    },
  );

  test(
    'every ignored flag names an upstream flag that is not in the catalog',
    () {
      final catalogFlags = _catalogFlags(catalog);
      final upstreamFlags = <String>{
        for (final definition in parsed.definitions)
          if (definition.isVisibleToServer) ...[
            ...definition.flags,
            ...definition.negatedFlags,
          ],
      };
      for (final entry in _ignoredFlags(overrides).entries) {
        expect(
          upstreamFlags,
          contains(entry.key),
          reason: '${entry.key} is not a llama-server flag',
        );
        expect(
          catalogFlags,
          isNot(contains(entry.key)),
          reason: '${entry.key} is in the catalog, so ignoring it is stale',
        );
        expect(entry.value, isNotEmpty, reason: entry.key);
      }
    },
  );

  test('every server-visible definition maps to a catalog parameter', () {
    final catalogIds = {
      for (final parameter in catalog.parameters) parameter.id,
    };
    final visibleIds = <String>{};
    for (final definition in parsed.definitions) {
      if (!definition.isVisibleToServer) {
        continue;
      }
      visibleIds.add(_idOf(definition));
    }
    // -np/--parallel is declared twice; the explicit SERVER branch wins.
    expect(
      catalogIds.containsAll(visibleIds),
      isTrue,
      reason: visibleIds.difference(catalogIds).join(', '),
    );
  });

  test('definitions llama-server cannot see are classified as unavailable', () {
    final visibleFlagSets = <String>{
      for (final definition in parsed.definitions)
        if (definition.isVisibleToServer) definition.flags.join('\u0000'),
    };
    final unavailable = {
      for (final parameter in catalog.parameters)
        if (parameter.exposure == ParamExposure.unsupported ||
            parameter.exposure == ParamExposure.removed)
          parameter.id,
    };
    final unclassified = <String>[];
    for (final definition in parsed.definitions) {
      if (definition.isVisibleToServer) {
        continue;
      }
      if (visibleFlagSets.contains(definition.flags.join('\u0000'))) {
        // A per-tool variant with the same tokens as a visible definition.
        continue;
      }
      if (!unavailable.contains(_idOf(definition))) {
        unclassified.add('${_idOf(definition)} (arg.cpp:${definition.line})');
      }
    }
    expect(unclassified, isEmpty, reason: unclassified.join('\n'));
  });

  test('the four exposure sets are disjoint', () {
    final byExposure = <ParamExposure, Set<String>>{
      for (final exposure in ParamExposure.values) exposure: <String>{},
    };
    for (final parameter in catalog.parameters) {
      byExposure[parameter.exposure]!.add(parameter.id);
    }
    for (final exposure in ParamExposure.values) {
      expect(byExposure[exposure], isNotEmpty, reason: '$exposure is empty');
    }
    final values = ParamExposure.values;
    for (var i = 0; i < values.length; i++) {
      for (var j = i + 1; j < values.length; j++) {
        expect(
          byExposure[values[i]]!.intersection(byExposure[values[j]]!),
          isEmpty,
          reason: '${values[i]} and ${values[j]} overlap',
        );
      }
    }
    final total = byExposure.values.fold<int>(
      0,
      (sum, ids) => sum + ids.length,
    );
    expect(total, catalog.parameters.length);
  });

  test('unavailable and managed parameters explain themselves', () {
    for (final parameter in catalog.parameters) {
      switch (parameter.exposure) {
        case ParamExposure.unsupported:
          expect(
            parameter.reason?.trim(),
            isNotEmpty,
            reason: '${parameter.id} has no reason',
          );
          expect(parameter.surfaces, isEmpty);
        case ParamExposure.removed:
          expect(
            parameter.reason?.trim(),
            isNotEmpty,
            reason: '${parameter.id} has no reason',
          );
          expect(parameter.surfaces, isEmpty);
        case ParamExposure.managed:
          expect(
            parameter.managedBy?.trim(),
            isNotEmpty,
            reason: '${parameter.id} has no managedBy',
          );
          expect(
            parameter.reason?.trim(),
            isNotEmpty,
            reason: '${parameter.id} has no reason',
          );
        case ParamExposure.configurable:
          break;
      }
    }
  });

  test('embedded parameters are a documented subset of the catalog', () {
    final embedded = catalog.forSurface(ParamSurface.embedded);
    expect(embedded, isNotEmpty);
    for (final parameter in embedded) {
      expect(
        _embeddedHonoured,
        contains(parameter.id),
        reason:
            '${parameter.id} is marked embedded but the native session cannot '
            'honour it',
      );
      expect(catalog.byId(parameter.id), same(parameter));
    }
    final honoured = catalog.parameters
        .where((parameter) => _embeddedHonoured.contains(parameter.id))
        .map((parameter) => parameter.id)
        .toSet();
    expect(honoured, _embeddedHonoured);
    for (final id in _embeddedHonoured) {
      expect(catalog.byId(id), isNotNull, reason: 'missing embedded id $id');
    }
  });

  test('the embedded chat template maps to the typed field', () {
    final ParameterSpec spec = catalog.byId('chat-template')!;
    final ModelParams params = ModelParams.defaults().copyWith(
      chatTemplate: 'chatml',
    );

    expect(spec.appliesTo(ParamSurface.embedded), isTrue);
    expect(ParameterValues.valueForModel(params, 'chat-template'), 'chatml');
  });

  test('the overrides list the same ids the catalog classifies', () {
    final catalogIds = {
      for (final parameter in catalog.parameters) parameter.id,
    };
    final groupMap = overrides['groupMap']! as Map<String, Object?>;
    final grouped = <String>[
      for (final value in groupMap.values)
        ...(value! as List<Object?>).cast<String>(),
    ];
    expect(
      grouped.toSet(),
      hasLength(grouped.length),
      reason: 'id grouped twice',
    );
    for (final id in grouped) {
      expect(catalogIds, contains(id), reason: 'groupMap lists unknown $id');
    }
    for (final parameter in catalog.parameters) {
      if (parameter.exposure == ParamExposure.configurable ||
          parameter.exposure == ParamExposure.managed) {
        expect(
          grouped,
          contains(parameter.id),
          reason: '${parameter.id} is not in groupMap',
        );
      }
    }
  });
}

Set<String> _catalogFlags(ParameterCatalog catalog) => {
  for (final parameter in catalog.parameters) ...parameter.flags,
  for (final parameter in catalog.parameters) ?parameter.negatedFlag,
};

String _idOf(UpstreamArgDefinition definition) {
  for (final flag in definition.flags) {
    if (flag.startsWith('--') && flag.length > 2) {
      return flag.substring(2);
    }
  }
  return definition.flags.first.replaceFirst(RegExp(r'^-+'), '');
}

Map<String, String> _ignoredFlags(Map<String, Object?> overrides) {
  final raw = overrides['ignoredFlags'];
  if (raw == null) {
    return const {};
  }
  final ignored = <String, String>{};
  for (final entry in (raw as List<Object?>)) {
    final map = entry! as Map<String, Object?>;
    ignored[map['flag']! as String] = map['reason']! as String;
  }
  return ignored;
}
