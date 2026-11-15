import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../l10n/app_localizations.dart';

/// The localized headline of an inference failure.
///
/// The code carries the category of the failure, so the label is a short
/// sentence the user can act on. The failure message and details stay the
/// technical text they are.
String inferenceFailureLabel(
  AppLocalizations l10n,
  InferenceFailureCode code,
) => switch (code) {
  InferenceFailureCode.engineUnavailable =>
    l10n.inferenceFailureEngineUnavailable,
  InferenceFailureCode.modelNotFound => l10n.inferenceFailureModelNotFound,
  InferenceFailureCode.invalidParams => l10n.inferenceFailureInvalidParams,
  InferenceFailureCode.engineBusy => l10n.inferenceFailureEngineBusy,
  InferenceFailureCode.cancelled => l10n.inferenceFailureCancelled,
  InferenceFailureCode.nativeError => l10n.inferenceFailureNativeError,
  InferenceFailureCode.libraryNotFound => l10n.inferenceFailureLibraryNotFound,
  InferenceFailureCode.libraryVersionMismatch =>
    l10n.inferenceFailureLibraryVersionMismatch,
  InferenceFailureCode.paramsLoadFailed =>
    l10n.inferenceFailureParamsLoadFailed,
  InferenceFailureCode.paramsSaveFailed =>
    l10n.inferenceFailureParamsSaveFailed,
  InferenceFailureCode.modelPathRequired =>
    l10n.inferenceFailureModelPathRequired,
  InferenceFailureCode.modelLoadFailed => l10n.inferenceFailureModelLoadFailed,
  InferenceFailureCode.promptRequired => l10n.inferenceFailurePromptRequired,
  InferenceFailureCode.modelNotReady => l10n.inferenceFailureModelNotReady,
  InferenceFailureCode.cancelFailed => l10n.inferenceFailureCancelFailed,
  InferenceFailureCode.unloadFailed => l10n.inferenceFailureUnloadFailed,
  InferenceFailureCode.streamEnded => l10n.inferenceFailureStreamEnded,
  _ => l10n.inferenceFailureUnknown,
};
