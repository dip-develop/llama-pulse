import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

import '../../support/catalog_files.dart';

void main() {
  final files = CatalogFiles.instance;
  final document = files.readYaml(files.catalog);
  final parameters = (document['parameters']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final groups = (document['groups']! as List<Object?>)
      .cast<Map<String, Object?>>();

  test('the digest covers the canonical catalog body', () {
    final body = <String, Object?>{
      'schemaVersion': document['schemaVersion'],
      'source': document['source'],
      'groups': document['groups'],
      'parameters': document['parameters'],
    };
    final expected = catalogDigest(
      body,
      (bytes) => sha256.convert(bytes).toString(),
    );

    expect(document['digest'], expected);
    expect(ParameterCatalog.v080.digest, expected);
    expect(document['digest'], startsWith('sha256:'));
  });

  test('the catalog records the vendored file hash', () {
    final source = document['source']! as Map<String, Object?>;
    final actual = sha256
        .convert(files.upstreamArgSource.readAsBytesSync())
        .toString();

    expect(source['sha256'], actual);
    expect(source['tag'], 'v0.8.0');
    expect(source['commit'], '8642541b255bfb5dc39cd351a178be09013a55d6');
    expect(source['surface'], 'llama-server');
    expect(ParameterCatalog.v080.upstreamFileSha256, actual);
    expect(ParameterCatalog.v080.upstreamTag, 'v0.8.0');
  });

  test('the generated Dart catalog mirrors the YAML catalog', () {
    expect(ParameterCatalog.v080.parameters, hasLength(parameters.length));
    for (var index = 0; index < parameters.length; index++) {
      final yaml = parameters[index];
      final spec = ParameterCatalog.v080.parameters[index];
      expect(spec.id, yaml['id']);
      expect(spec.displayName, yaml['displayName']);
      expect(spec.summary, yaml['summary']);
      expect(spec.description, yaml['description']);
      expect(spec.flags, yaml['flags']);
      expect(spec.negatedFlag, yaml['negatedFlag']);
      expect(spec.type.wireName, yaml['type']);
      expect(spec.arity, yaml['arity']);
      expect(spec.defaultValue, yaml['defaultValue']);
      expect(spec.min, yaml['min']);
      expect(spec.max, yaml['max']);
      expect(spec.step, yaml['step']);
      expect(spec.allowed, yaml['allowed']);
      expect(spec.itemType?.wireName, yaml['itemType']);
      expect(spec.repeatable, yaml['repeatable']);
      expect(spec.group, yaml['group']);
      expect([
        for (final surface in spec.surfaces) surface.wireName,
      ], yaml['surfaces']);
      expect(spec.exposure.wireName, yaml['exposure']);
      expect(spec.owner, yaml['owner']);
      expect(spec.managedBy, yaml['managedBy']);
      expect(spec.envVar, yaml['envVar']);
      expect(spec.advanced, yaml['advanced']);
      expect(spec.deprecated, yaml['deprecated']);
      expect(spec.replacement, yaml['replacement']);
      expect(spec.requiresExistingPath, yaml['requiresExistingPath']);
      expect(spec.warning, yaml['warning']);
      expect(spec.reason, yaml['reason']);
    }
  });

  test('ids and flag tokens are unique', () {
    final ids = <String>{};
    final flags = <String>{};
    for (final parameter in parameters) {
      final id = parameter['id']! as String;
      expect(ids.add(id), isTrue, reason: 'id $id is declared twice');
      for (final flag in _strings(parameter, 'flags')) {
        expect(flags.add(flag), isTrue, reason: '$flag is declared twice');
      }
      final negated = parameter['negatedFlag'];
      if (negated != null) {
        expect(
          flags.add(negated as String),
          isTrue,
          reason: '$negated is declared twice',
        );
      }
    }
  });

  test('every group is defined, ordered and non-empty', () {
    final groupIds = <String>{};
    final orders = <int>{};
    for (final group in groups) {
      final id = group['id']! as String;
      expect(groupIds.add(id), isTrue, reason: 'duplicate group $id');
      expect(orders.add(group['order']! as int), isTrue);
      expect(group['name'], isNotEmpty);
      expect(
        parameters.any((parameter) => parameter['group'] == id),
        isTrue,
        reason: 'group $id has no parameters',
      );
    }
    expect(
      [for (final group in groups) group['order']! as int],
      orderedEquals(
        [for (final group in groups) group['order']! as int]..sort(),
      ),
    );
    for (final parameter in parameters) {
      expect(groupIds, contains(parameter['group']));
    }
  });

  test('every owner names a field on ServerConfig or ModelParams', () {
    final entityFields = <String>{
      ..._getterNames(
        File(
          '${files.repoRoot.path}/packages/llama_pulse_core/lib/src/domain/'
          'entities/server_config.dart',
        ),
      ),
      ..._getterNames(
        File(
          '${files.repoRoot.path}/packages/llama_pulse_core/lib/src/domain/'
          'entities/model_params.dart',
        ),
      ),
    };
    expect(entityFields, contains('contextSize'));

    for (final parameter in parameters) {
      final owner = parameter['owner'];
      if (owner == null) {
        continue;
      }
      expect(
        entityFields,
        contains(owner),
        reason:
            '${parameter['id']} names owner "$owner", which is not a getter on '
            'ServerConfig or ModelParams',
      );
    }
  });

  test('the catalog lookup helpers agree with the list', () {
    expect(ParameterCatalog.v080.all, ParameterCatalog.v080.parameters);
    expect(ParameterCatalog.v080.groups, hasLength(groups.length));
    for (final parameter in ParameterCatalog.v080.parameters) {
      expect(ParameterCatalog.v080.byId(parameter.id), same(parameter));
      for (final flag in parameter.flags) {
        expect(ParameterCatalog.v080.byFlag(flag), same(parameter));
      }
      final negated = parameter.negatedFlag;
      if (negated != null) {
        expect(ParameterCatalog.v080.byFlag(negated), same(parameter));
      }
    }
    expect(ParameterCatalog.v080.byId('definitely-not-a-flag'), isNull);
    expect(ParameterCatalog.v080.byFlag('--definitely-not-a-flag'), isNull);
  });
}

Iterable<String> _strings(Map<String, Object?> map, String key) =>
    (map[key]! as List<Object?>).cast<String>();

Set<String> _getterNames(File file) {
  final names = <String>{};
  for (final line in file.readAsLinesSync()) {
    final match = RegExp(r'\bget\s+(\w+)\s*[;=]').firstMatch(line);
    if (match != null) {
      names.add(match.group(1)!);
    }
  }
  return names;
}
