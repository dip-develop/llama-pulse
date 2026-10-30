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

final _directive = RegExp('''^\\s*(?:import|export)\\s+['"]([^'"]+)['"]''');
final _forbiddenJson = RegExp(r'\bjson(?:Encode|Decode)\s*\(');

void main() {
  test('core has no UI, state, storage or JSON dependencies', () {
    final violations = <String>[];
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .where((file) => !file.path.endsWith('.g.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
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
        if (_forbiddenJson.hasMatch(line)) {
          violations.add('${file.path}:${index + 1}: forbidden JSON usage');
        }
      }
    }

    // dart:ffi is deliberately allowed: the bridge lives in core and only
    // runs inside the worker isolate.
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
