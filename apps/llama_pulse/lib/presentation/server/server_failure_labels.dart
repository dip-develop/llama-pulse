import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../l10n/app_localizations.dart';

/// The localized headline of a server failure.
///
/// The code carries the category of the failure, so the label is a short
/// sentence the user can act on. The failure message and details stay the
/// technical text they are.
String serverFailureLabel(
  AppLocalizations l10n,
  ServerFailureCode code,
) => switch (code) {
  ServerFailureCode.binaryNotFound => l10n.serverFailureBinaryNotFound,
  ServerFailureCode.binaryNotExecutable =>
    l10n.serverFailureBinaryNotExecutable,
  ServerFailureCode.unsupportedVersion => l10n.serverFailureUnsupportedVersion,
  ServerFailureCode.portInUse => l10n.serverFailurePortInUse,
  ServerFailureCode.modelNotFound => l10n.serverFailureModelNotFound,
  ServerFailureCode.invalidConfig => l10n.serverFailureInvalidConfig,
  ServerFailureCode.startupTimeout => l10n.serverFailureStartupTimeout,
  ServerFailureCode.processExited => l10n.serverFailureProcessExited,
  ServerFailureCode.healthCheckFailed => l10n.serverFailureHealthCheckFailed,
  ServerFailureCode.httpError => l10n.serverFailureHttpError,
  ServerFailureCode.stateUnreadable => l10n.serverFailureStateUnreadable,
  ServerFailureCode.configLoadFailed => l10n.serverFailureConfigLoadFailed,
  ServerFailureCode.configSaveFailed => l10n.serverFailureConfigSaveFailed,
  ServerFailureCode.binaryInspectionFailed =>
    l10n.serverFailureBinaryInspectionFailed,
  ServerFailureCode.startFailed => l10n.serverFailureStartFailed,
  ServerFailureCode.stopFailed => l10n.serverFailureStopFailed,
  ServerFailureCode.streamEnded => l10n.serverFailureStreamEnded,
  ServerFailureCode.externalRun => l10n.serverFailureExternalRun,
  _ => l10n.serverFailureUnknown,
};

/// The one-line form of a server failure: the label and, when the failure
/// carries one, its technical message.
String serverFailureText(AppLocalizations l10n, ServerFailure failure) {
  final String label = serverFailureLabel(l10n, failure.code);
  final String message = failure.message.trim();
  if (message.isEmpty) {
    return label;
  }
  return '$label: $message';
}
