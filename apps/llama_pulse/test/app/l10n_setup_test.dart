import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/l10n/app_localizations.dart';
import 'package:llama_pulse/presentation/home/home_shell.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('the root app loads the English delegate', (
    WidgetTester tester,
  ) async {
    await pumpLlamaPulse(tester, locale: const Locale('en'));

    // The shell sits below the app's `MaterialApp`, so this lookup goes through
    // the delegates and the locale `LlamaPulseApp` installs.
    final AppLocalizations? l10n = AppLocalizations.of(
      tester.element(find.byType(HomeShell)),
    );

    expect(l10n, isNotNull);
    expect(l10n!.localeName, 'en');
    expect(l10n.appTitle, 'LlamaPulse');
    expect(l10n.homeTitleServer, 'LlamaPulse — Server');
    expect(l10n.homeTitleChat, 'LlamaPulse — Chat');
    expect(l10n.homeTitleRuntime, 'LlamaPulse — Runtime');
    expect(l10n.navServer, 'Server');
    expect(l10n.navChat, 'Chat');
    expect(l10n.navRuntime, 'Runtime');
    expect(l10n.navChatExperimental, 'Chat (experimental)');
    expect(
      l10n.chatExperimentalBanner,
      'Experimental — embedded chat. The server is the primary path.',
    );
    expect(
      Localizations.localeOf(tester.element(find.byType(HomeShell))),
      const Locale('en'),
    );
  });

  test('the app supports English only', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
    expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
  });

  test('the English delegate resolves the template locale', () async {
    final AppLocalizations loaded = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    expect(loaded.appTitle, 'LlamaPulse');
    expect(loaded.homeTitleServer, 'LlamaPulse — Server');
    expect(loaded.navChatExperimental, 'Chat (experimental)');
  });
}
