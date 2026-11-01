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

/// `dart:ffi` is only allowed in the llama.cpp bridge.
const _ffiAllowedPrefix = 'lib/src/data/inference/native/';

final _directive = RegExp('''^\\s*(?:import|export)\\s+['"]([^'"]+)['"]''');
final _jsonEncode = RegExp(r'\bjsonEncode\s*\(');
final _jsonDecode = RegExp(r'\bjsonDecode\s*\(');
final _ffiDirective = RegExp('''^\\s*import\\s+['"]dart:ffi['"]''');
final _exportDirective = RegExp('''^\\s*export\\s+['"]([^'"]+)['"]''');

String _normalized(String path) => path.replaceAll(r'\', '/');

bool _allowsJsonDecode(String path) {
  final normalized = _normalized(path);
  return normalized.startsWith(_jsonDecodeAllowedPath) ||
      normalized.contains('/$_jsonDecodeAllowedPath');
}

bool _allowsFfi(String path) {
  final normalized = _normalized(path);
  return normalized.startsWith(_ffiAllowedPrefix) ||
      normalized.contains('/$_ffiAllowedPrefix');
}

List<File> _libFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('.g.dart'))
        .toList();

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
      if (_ffiDirective.hasMatch(line) && !_allowsFfi(file.path)) {
        violations.add(
          '${file.path}:${index + 1}: dart:ffi is only allowed under '
          '$_ffiAllowedPrefix',
        );
      }
      final export = _exportDirective.firstMatch(line);
      if (export != null && export.group(1)!.contains('native/')) {
        violations.add(
          "${file.path}:${index + 1}: exports '${export.group(1)}'; the FFI "
          'bridge stays internal',
        );
      }
    }
  }
  return violations;
}

void main() {
  test('core has no UI, state, storage or JSON encoding dependencies', () {
    final violations = _scan(_libFiles());

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

  test('dart:ffi only appears in the native bridge directory', () {
    final directory = Directory.systemTemp.createTempSync('llama_pulse_arch_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final allowed = File('${directory.path}/$_ffiAllowedPrefix/bridge.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync("import 'dart:ffi';\n");
    final forbidden = File('${directory.path}/lib/src/domain/loader.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync("import 'dart:ffi';\n");

    final violations = _scan([allowed, forbidden]);

    expect(violations, hasLength(1));
    expect(violations.single, contains('loader.dart:1'));
    expect(violations.single, contains('dart:ffi'));
  });

  test('the public library does not export the native bridge', () {
    final barrel = File('lib/llama_pulse_core.dart');

    final violations = _scan([barrel]);

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
