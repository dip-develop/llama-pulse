import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../l10n/app_localizations.dart';

/// Category of the last runtime error.
///
/// The bloc reports the category and the technical detail; the UI turns the
/// category into a localized sentence.
enum RuntimeErrorCode {
  /// The host detection and the runtime index could not be read.
  statusReadFailed,

  /// The backend has no archive for this host.
  unavailableOnHost,

  /// The install failed.
  installFailed,

  /// A selection or a removal failed.
  actionFailed,
}

/// Category of the last runtime notice.
enum RuntimeNoticeCode {
  /// The download is being cancelled.
  cancelling,

  /// The user cancelled the install.
  installCancelled,

  /// A backend was installed.
  installed,

  /// A runtime was selected.
  selected,

  /// A runtime was removed.
  removed,
}

/// The localized headline of a runtime error.
String runtimeErrorLabel(AppLocalizations l10n, RuntimeErrorCode code) =>
    switch (code) {
      RuntimeErrorCode.statusReadFailed => l10n.runtimeErrorStatusReadFailed,
      RuntimeErrorCode.unavailableOnHost => l10n.runtimeErrorUnavailableOnHost,
      RuntimeErrorCode.installFailed => l10n.runtimeErrorInstallFailed,
      RuntimeErrorCode.actionFailed => l10n.runtimeErrorActionFailed,
    };

/// The localized sentence of a runtime error, with its technical detail.
String runtimeErrorText(
  AppLocalizations l10n,
  RuntimeErrorCode code,
  String detail,
) {
  final String label = runtimeErrorLabel(l10n, code);
  final String message = detail.trim();
  if (message.isEmpty) {
    return label;
  }
  return '$label: $message';
}

/// The localized sentence of a runtime notice.
///
/// [detail] names the backend or the `tag/backend` pair the notice is about.
String runtimeNoticeText(
  AppLocalizations l10n,
  RuntimeNoticeCode code,
  String detail,
) => switch (code) {
  RuntimeNoticeCode.cancelling => l10n.runtimeNoticeCancelling,
  RuntimeNoticeCode.installCancelled => l10n.runtimeNoticeInstallCancelled,
  RuntimeNoticeCode.installed => l10n.runtimeNoticeInstalled(detail),
  RuntimeNoticeCode.selected => l10n.runtimeNoticeSelected(detail),
  RuntimeNoticeCode.removed => l10n.runtimeNoticeRemoved(detail),
};

/// The localized headline of a runtime gate verdict.
String runtimeGateVerdictLabel(
  AppLocalizations l10n,
  RuntimeGateVerdict verdict,
) => switch (verdict) {
  RuntimeGateVerdict.notInstalled => l10n.runtimeGateNotInstalled,
  RuntimeGateVerdict.exact => l10n.runtimeGateExact,
  RuntimeGateVerdict.attested => l10n.runtimeGateAttested,
  RuntimeGateVerdict.unknown => l10n.runtimeGateUnknown,
  RuntimeGateVerdict.rejected => l10n.runtimeGateRejected,
};
