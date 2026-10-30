import 'dart:io';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:test/test.dart';

String _withoutBuild(String version) => version.split('+').first;

void main() {
  test('pubspec version matches cliVersion', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);

    final pubspecVersion = match?.group(1);
    expect(pubspecVersion, isNotNull);
    if (pubspecVersion == null) {
      return;
    }

    expect(_withoutBuild(pubspecVersion), _withoutBuild(cliVersion));
  });
}
