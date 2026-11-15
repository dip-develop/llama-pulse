import '../../l10n/app_localizations.dart';
import 'bloc/runtime_state.dart';

/// The one-line description of the detected host.
///
/// The state holds the technical parts (operating system, architecture,
/// platform and GPUs); the sentence around them is localized.
String runtimeHardwareSummary(AppLocalizations l10n, RuntimeState state) {
  final String? operatingSystem = state.operatingSystem;
  if (operatingSystem == null) {
    return l10n.runtimeDetectingHost;
  }
  final String platform =
      state.platform?.id ?? l10n.runtimeUnsupportedHostShort;
  final String gpus = state.hasGpu
      ? (state.gpuSummary ?? '')
      : l10n.runtimeNoGpuDetected;
  return '$operatingSystem · $platform · $gpus';
}
