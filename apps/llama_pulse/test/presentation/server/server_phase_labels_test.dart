import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/l10n/app_localizations.dart';
import 'package:llama_pulse/presentation/server/server_phase_labels.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

void main() {
  test('every phase has a localized label', () async {
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    expect(serverPhaseLabel(l10n, ServerPhase.stopped), 'Stopped');
    expect(serverPhaseLabel(l10n, ServerPhase.starting), 'Starting');
    expect(serverPhaseLabel(l10n, ServerPhase.running), 'Running');
    expect(serverPhaseLabel(l10n, ServerPhase.stopping), 'Stopping');
    expect(serverPhaseLabel(l10n, ServerPhase.failed), 'Failed');
  });
}
