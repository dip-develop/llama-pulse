import 'dart:io';

import 'package:test/test.dart';

const _forbiddenImports = [
  'package:flutter/',
  'dart:ui',
  'package:shared_preferences/',
  'package:file_selector/',
  'package:flutter_bloc/',
  'package:bloc/',
  'package:get_it/',
  'package:injectable/',
  'package:hive_ce/',
  'package:json_annotation/',
];

const String _jsonDecodeAllowedPath = 'lib/src/data/server/';

final _directive = RegExp('''^\\s*(?:import|export)\\s+['"]([^'"]+)['"]''');
final _jsonEncode = RegExp(r'\bjsonEncode\s*\(');
final _jsonDecode = RegExp(r'\bjsonDecode\s*\(');

bool _allowsJsonDecode(String path) {
  final normalized = path.replaceAll(r'\', '/');
  return normalized.startsWith(_jsonDecodeAllowedPath) ||
      normalized.contains('/$_jsonDecodeAllowedPath');
}

List<String> _scan(Iterable<File> files) {
  final violations = <String>[];
  final sorted = files.toList()..sort((a, b) => a.path.compareTo(b.path));
  for (final file in sorted) {
    if (!file.path.endsWith('.dart') || file.path.endsWith('.g.dart')) {
      continue;
    }
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('part ') || trimmed.startsWith('part of ')) {
        continue;
      }
      final directive = _directive.firstMatch(line);
      if (directive != null) {
        final uri = directive.group(1)!;
        if (_forbiddenImports.any(uri.startsWith)) {
          violations.add(
            '${file.path}:${index + 1}: forbidden import \'$uri\'',
          );
        }
      }
      if (_jsonEncode.hasMatch(line)) {
        violations.add('${file.path}:${index + 1}: forbidden jsonEncode usage');
      }
      if (_jsonDecode.hasMatch(line) && !_allowsJsonDecode(file.path)) {
        violations.add(
          '${file.path}:${index + 1}: jsonDecode is only allowed under '
          '$_jsonDecodeAllowedPath',
        );
      }
    }
  }
  return violations;
}

void main() {
  test('core has no UI, state, storage or JSON encoding dependencies', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .toList();

    final violations = _scan(files);

    // dart:ffi is deliberately allowed: the bridge lives in core and only
    // runs inside the worker isolate.
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('jsonDecode is allowed only under lib/src/data/server', () {
    final directory = Directory.systemTemp.createTempSync('llama_pulse_arch_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final allowed = File('${directory.path}/lib/src/data/server/monitor.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('final decoded = jsonDecode(body);\n');
    final forbidden = File('${directory.path}/lib/src/domain/model.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('final decoded = jsonDecode(body);\n');

    final violations = _scan([allowed, forbidden]);

    expect(violations, hasLength(1));
    expect(violations.single, contains('model.dart:1'));
    expect(violations.single, contains('jsonDecode'));
  });

  test('jsonEncode stays forbidden even under lib/src/data/server', () {
    final directory = Directory.systemTemp.createTempSync('llama_pulse_arch_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/lib/src/data/server/encoder.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('final encoded = jsonEncode(value);\n');

    final violations = _scan([file]);

    expect(violations, hasLength(1));
    expect(violations.single, contains('encoder.dart:1'));
    expect(violations.single, contains('jsonEncode'));
  });
}
