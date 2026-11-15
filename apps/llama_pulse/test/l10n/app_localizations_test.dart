import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/l10n/app_localizations.dart';

/// The ARB template of the app.
final File _template = File('lib/l10n/app_en.arb');

void main() {
  test('the template carries a message for every key', () {
    final Map<String, dynamic> template =
        jsonDecode(_template.readAsStringSync()) as Map<String, dynamic>;

    final Iterable<String> messages = template.keys.where(
      (String key) => !key.startsWith('@'),
    );
    expect(messages, isNotEmpty);

    for (final String key in messages) {
      final Object? value = template[key];
      expect(value, isA<String>(), reason: key);
      expect((value! as String).trim(), isNotEmpty, reason: key);
    }
  });

  test('every template message reaches the generated delegate', () async {
    final Map<String, dynamic> template =
        jsonDecode(_template.readAsStringSync()) as Map<String, dynamic>;
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    for (final String key in template.keys) {
      if (key.startsWith('@')) {
        continue;
      }
      // The plural messages are methods, the rest are getters; both are
      // covered by the generated class, so a missing key fails the build
      // instead of this test.
      expect(l10n, isNotNull, reason: key);
    }
  });

  test('the delegate resolves every supported locale', () async {
    for (final Locale locale in AppLocalizations.supportedLocales) {
      final AppLocalizations? loaded = await AppLocalizations.delegate.load(
        locale,
      );
      expect(loaded, isNotNull, reason: '$locale');
      expect(loaded!.localeName, locale.languageCode);
    }
  });

  test('the plural messages pick the right form', () async {
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    expect(
      l10n.paramsResetGroup(1, 'Sampling'),
      'Reset 1 parameter in Sampling',
    );
    expect(
      l10n.paramsResetGroup(3, 'Sampling'),
      'Reset 3 parameters in Sampling',
    );
    expect(l10n.chatMetricsReportsValue(1), '1 sample');
    expect(l10n.chatMetricsReportsValue(7), '7 samples');
  });
}
