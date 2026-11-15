import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../l10n/app_localizations.dart';

/// Human label of a [ServerPhase] for the dashboard chrome.
///
/// The wire value stays [ServerPhase.name]: only the label is localized, so
/// the persisted state, the CLI output and the log lines keep the phase names.
String serverPhaseLabel(AppLocalizations l10n, ServerPhase phase) =>
    switch (phase) {
      ServerPhase.running => l10n.serverPhaseRunning,
      ServerPhase.starting => l10n.serverPhaseStarting,
      ServerPhase.stopping => l10n.serverPhaseStopping,
      ServerPhase.failed => l10n.serverPhaseFailed,
      _ => l10n.serverPhaseStopped,
    };
