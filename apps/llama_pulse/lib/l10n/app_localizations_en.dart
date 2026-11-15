// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LlamaPulse';

  @override
  String get homeTitleServer => 'LlamaPulse — Server';

  @override
  String get homeTitleChat => 'LlamaPulse — Chat';

  @override
  String get homeTitleRuntime => 'LlamaPulse — Runtime';

  @override
  String get navServer => 'Server';

  @override
  String get navChat => 'Chat';

  @override
  String get navRuntime => 'Runtime';

  @override
  String get navChatExperimental => 'Chat (experimental)';

  @override
  String get chatExperimentalBanner =>
      'Experimental — embedded chat. The server is the primary path.';

  @override
  String get serverDemoBanner =>
      'Demo server — no llama-server process is started.';

  @override
  String get serverStatusTitle => 'Server';

  @override
  String get serverStatusHealth => 'Health';

  @override
  String get serverStatusSupervisorPid => 'Supervisor pid';

  @override
  String get serverStatusServerPid => 'Server pid';

  @override
  String get serverStatusModel => 'Model';

  @override
  String get serverStatusBinary => 'Binary';

  @override
  String get serverStatusBinaryNotLocated => 'not located';

  @override
  String get serverStatusVersion => 'Version';

  @override
  String get serverStatusExternalRun =>
      'Started outside this app — stop it with llamapulse stop.';

  @override
  String get serverStatusUptime => 'Uptime';

  @override
  String get serverStatusLastExitCode => 'Last exit code';

  @override
  String get serverStatusLastFailure => 'Last failure';

  @override
  String get serverStatusStart => 'Start';

  @override
  String get serverStatusStop => 'Stop';

  @override
  String get serverPhaseRunning => 'Running';

  @override
  String get serverPhaseStarting => 'Starting';

  @override
  String get serverPhaseStopping => 'Stopping';

  @override
  String get serverPhaseFailed => 'Failed';

  @override
  String get serverPhaseStopped => 'Stopped';

  @override
  String get serverEndpointTitle => 'Endpoint';

  @override
  String get serverEndpointCopy => 'Copy';

  @override
  String get serverEndpointTesting => 'Testing…';

  @override
  String get serverEndpointTestConnection => 'Test connection';

  @override
  String serverEndpointConnected(int latencyMs) {
    return 'Connected ($latencyMs ms)';
  }

  @override
  String get serverMetricsTitle => 'Metrics';

  @override
  String get serverMetricsEmpty => 'Metrics appear once the server is running.';

  @override
  String get serverMetricsGeneration => 'Generation';

  @override
  String get serverMetricsPrompt => 'Prompt';

  @override
  String get serverMetricsActiveSlots => 'Active slots';

  @override
  String get serverMetricsRequests => 'Requests';

  @override
  String serverMetricsRequestsValue(int processing, int deferred) {
    return '$processing processing · $deferred deferred';
  }

  @override
  String get serverMetricsPredictedTokens => 'Predicted tokens';

  @override
  String get serverMetricsContextUsage => 'Context usage';

  @override
  String get serverMetricsContextNotExposed => 'not exposed';

  @override
  String get serverLogTitle => 'Log';

  @override
  String get serverLogClear => 'Clear';

  @override
  String get serverLogEmpty => 'No log lines yet.';

  @override
  String get serverConfigTitle => 'Server configuration';

  @override
  String get serverConfigUnsavedChanges => 'Unsaved changes';

  @override
  String get serverConfigApplyOnNextStart => 'Changes apply on the next start.';

  @override
  String get serverConfigModelPath => 'Model path';

  @override
  String get modelPathExample => '/models/model.gguf';

  @override
  String get serverConfigBinaryPath => 'llama-server binary';

  @override
  String get serverConfigBinaryPathHint => 'auto-detected when empty';

  @override
  String get serverConfigHost => 'Host';

  @override
  String get serverConfigPort => 'Port';

  @override
  String get serverConfigContextSize => 'Context size';

  @override
  String get serverConfigThreads => 'Threads';

  @override
  String get serverConfigGpuLayers => 'GPU layers';

  @override
  String get serverConfigParallelSlots => 'Parallel slots';

  @override
  String get serverConfigModelAlias => 'Model alias';

  @override
  String get serverConfigApiKey => 'API key';

  @override
  String get serverConfigApiKeyHint => 'empty disables authentication';

  @override
  String get serverConfigReveal => 'Reveal';

  @override
  String get serverConfigHide => 'Hide';

  @override
  String get serverConfigFlashAttention => 'Flash attention';

  @override
  String get serverConfigMlockSubtitle => 'Lock the model in RAM';

  @override
  String get serverConfigMmapSubtitle => 'Memory-map the model file';

  @override
  String get serverConfigExtraArgs => 'Extra arguments';

  @override
  String get serverConfigExtraArgsHint => 'one argument per line';

  @override
  String get serverConfigStartupTimeout => 'Startup timeout (s)';

  @override
  String get saveAction => 'Save';

  @override
  String get reloadAction => 'Reload';

  @override
  String get browseAction => 'Browse';

  @override
  String get paramsTitleServer => 'Server parameters';

  @override
  String get paramsSubtitleServer =>
      'Every other llama-server flag. The essentials stay in the form above and are saved with them.';

  @override
  String get paramsSearchHint => 'Search parameters';

  @override
  String get paramsModifiedOnly => 'Modified only';

  @override
  String get paramsExpandAll => 'Expand all';

  @override
  String get paramsCollapseAll => 'Collapse all';

  @override
  String get paramsEmpty => 'No parameters match';

  @override
  String paramsCount(int modified, int available) {
    return '$modified modified / $available available';
  }

  @override
  String get paramsUndo => 'Undo';

  @override
  String paramsResetParameter(String name) {
    return 'Reset $name';
  }

  @override
  String paramsResetGroup(int count, String group) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reset $count parameters in $group',
      one: 'Reset 1 parameter in $group',
    );
    return '$_temp0';
  }

  @override
  String get paramsResetToDefault => 'Reset to default';

  @override
  String paramsEffectiveValue(String value) {
    return 'Effective value: $value';
  }

  @override
  String paramsUseReplacement(String replacement) {
    return 'Use $replacement instead.';
  }

  @override
  String get paramsResetGroupTooltip => 'Reset this group';

  @override
  String get paramsDefaultHint => 'default';

  @override
  String paramsManagedBy(String owner) {
    return 'Managed by $owner.';
  }

  @override
  String get paramsUnsupportedReason =>
      'llama-server does not accept this parameter.';

  @override
  String get paramsRemovedReason => 'llama.cpp removed this parameter.';

  @override
  String paramsSelectFile(String name) {
    return 'Select $name';
  }

  @override
  String paramTooltipNegated(String flag) {
    return 'Negated form: $flag';
  }

  @override
  String paramTooltipType(String valueType) {
    return 'Type: $valueType';
  }

  @override
  String paramTooltipDefault(String value) {
    return 'Default: $value';
  }

  @override
  String get paramTooltipDynamic => 'dynamic';

  @override
  String paramTooltipRange(String range) {
    return 'Range: $range';
  }

  @override
  String paramTooltipEnvironment(String variable) {
    return 'Environment: $variable';
  }

  @override
  String paramTooltipWarning(String warning) {
    return 'Warning: $warning';
  }

  @override
  String paramTooltipNote(String reason) {
    return 'Note: $reason';
  }

  @override
  String paramTooltipReplacedBy(String replacement) {
    return 'Replaced by: $replacement';
  }

  @override
  String get paramTypeTwoValues => 'two values on separate lines';

  @override
  String get paramTypeSwitch => 'switch';

  @override
  String get paramTypeInteger => 'integer';

  @override
  String get paramTypeNumber => 'number';

  @override
  String paramTypeOneOf(String values) {
    return 'one of: $values';
  }

  @override
  String get paramTypePath => 'path';

  @override
  String get paramTypeText => 'text';

  @override
  String paramTypeOnePerLine(String valueType) {
    return '$valueType, one per line';
  }

  @override
  String paramTypeCommaSeparated(String valueType) {
    return '$valueType, comma separated';
  }

  @override
  String paramRangeStep(String step) {
    return 'step $step';
  }

  @override
  String paramRangeSteps(String bounds, String step) {
    return '$bounds in steps of $step';
  }

  @override
  String get chatDemoBanner => 'Demo engine — output is synthetic.';

  @override
  String get chatStatusIdle => 'Idle';

  @override
  String get chatStatusLoadingModel => 'Loading model';

  @override
  String get chatStatusReady => 'Ready';

  @override
  String get chatStatusGenerating => 'Generating';

  @override
  String get chatStatusCancelling => 'Cancelling';

  @override
  String get chatStatusError => 'Error';

  @override
  String get chatPromptLabel => 'Prompt';

  @override
  String get chatPromptHint => 'Ask the model something…';

  @override
  String get chatGenerate => 'Generate';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get unloadAction => 'Unload';

  @override
  String get chatConversationTitle => 'Conversation';

  @override
  String get chatClearConversation => 'Clear conversation';

  @override
  String get chatNoMessages => 'No messages yet.';

  @override
  String get chatRoleYou => 'You';

  @override
  String get chatRoleAssistant => 'Assistant';

  @override
  String get chatRoleTool => 'Tool';

  @override
  String get chatMetricsTitle => 'Metrics';

  @override
  String get chatMetricsEmpty => 'Metrics appear here after a generation.';

  @override
  String get chatMetricsTokensPerSecond => 'Tokens/sec';

  @override
  String get chatMetricsPromptEval => 'Prompt eval';

  @override
  String get chatMetricsGeneratedTokens => 'Generated tokens';

  @override
  String get chatMetricsPromptTokens => 'Prompt tokens';

  @override
  String get chatMetricsTimeToFirstToken => 'Time to first token';

  @override
  String get chatMetricsReports => 'Reports';

  @override
  String chatMetricsReportsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samples',
      one: '1 sample',
    );
    return '$_temp0';
  }

  @override
  String get chatModelParamsTitle => 'Model parameters';

  @override
  String get chatModelParamsHint => 'Changes apply to the next load.';

  @override
  String get chatModelPath => 'Model path';

  @override
  String get chatContextSize => 'Context size';

  @override
  String get chatGpuLayers => 'GPU layers';

  @override
  String get chatThreads => 'Threads';

  @override
  String get chatTemperature => 'Temperature';

  @override
  String get chatTopP => 'Top-p';

  @override
  String get chatTopK => 'Top-k';

  @override
  String get chatMaxTokens => 'Max tokens';

  @override
  String get chatTemplateLabel => 'Chat template';

  @override
  String get chatTemplateHint => 'Model default, a built-in name, or \"none\"';

  @override
  String get chatSystemPrompt => 'System prompt';

  @override
  String get chatSystemPromptHint =>
      'Prepended as the system message of each chat request';

  @override
  String get chatApplyTemplate => 'Apply chat template';

  @override
  String get chatApplyTemplateSubtitle =>
      'Off sends the raw prompt even when a template is set.';

  @override
  String get chatLoadModel => 'Load model';

  @override
  String get chatParamsTitle => 'Chat parameters';

  @override
  String get chatParamsSubtitle =>
      'Every other llama-cli flag for this session. The essentials stay in the form above and are saved with them.';

  @override
  String get chatManagedGroupName => 'Set in the essentials form';

  @override
  String get chatServerOnlyGroupName => 'Not available in the embedded engine';

  @override
  String get chatServerOnlyReason =>
      'embedded engine cannot honor this parameter yet';

  @override
  String get chatManagedGroupReason =>
      'Set by the essentials form above; edit it there and save once for both.';

  @override
  String get runtimeTitle => 'Runtime';

  @override
  String get runtimeRefresh => 'Refresh';

  @override
  String get runtimeDetectingHost => 'Detecting the host…';

  @override
  String get runtimeDetecting => 'Detecting…';

  @override
  String get runtimeRecommended => 'Recommended';

  @override
  String runtimeRecommendedBackend(String backend) {
    return 'Recommended: $backend';
  }

  @override
  String runtimeRecommendedReason(String backend, String reason) {
    return 'Recommended: $backend — $reason';
  }

  @override
  String get runtimeUnsupportedHost =>
      'The pinned release has no archive for this host.';

  @override
  String runtimeInstalling(String backend) {
    return 'Installing $backend';
  }

  @override
  String runtimeInstallingProgress(String backend, int percent) {
    return 'Installing $backend: $percent%';
  }

  @override
  String runtimeProgressValue(int percent, String received, String total) {
    return '$percent% · $received of $total';
  }

  @override
  String runtimeProgressRate(String rate) {
    return '$rate/s';
  }

  @override
  String get runtimeAvailableBackends => 'Available backends';

  @override
  String get runtimeNoBackendAvailable =>
      'No backend is available for this host.';

  @override
  String get runtimeInstalled => 'Installed';

  @override
  String get runtimeInstall => 'Install';

  @override
  String get runtimeReinstall => 'Reinstall';

  @override
  String get runtimeSelect => 'Select';

  @override
  String get runtimeSelected => 'Selected';

  @override
  String get runtimeRemove => 'Remove';

  @override
  String runtimeRemoveTitle(String id) {
    return 'Remove $id?';
  }

  @override
  String get runtimeRemoveMessage =>
      'The runtime directory and its manifest are deleted.';

  @override
  String get runtimeNoRuntimesInstalled => 'No runtimes installed yet.';

  @override
  String get runtimeGateLabel => 'Gate';

  @override
  String runtimeGateValue(String verdict, String reason) {
    return '$verdict — $reason';
  }

  @override
  String runtimeGateSummary(String verdict, String reason) {
    return 'Gate: $verdict — $reason';
  }

  @override
  String runtimeUnavailable(String reason) {
    return 'Unavailable: $reason';
  }

  @override
  String get runtimeHardware => 'Hardware';

  @override
  String get runtimeNone => 'none';

  @override
  String get runtimeInstallRuntime => 'Install runtime';

  @override
  String runtimeInstallTitle(String backend) {
    return 'Install $backend';
  }

  @override
  String get runtimeDownload => 'Download';

  @override
  String get runtimeCudaRuntime => 'CUDA runtime';

  @override
  String get runtimePlatform => 'Platform';

  @override
  String get runtimeUnsupported => 'unsupported';

  @override
  String runtimeDriverRequirement(String requirement) {
    return 'Driver requirement: $requirement';
  }

  @override
  String get runtimeCudaNote =>
      'The CUDA runtime is a second archive bundled only when you install a CUDA backend.';

  @override
  String get runtimeUnknownSize => 'unknown';

  @override
  String get runtimeNoGpuDetected => 'no GPU detected';

  @override
  String get runtimeUnsupportedHostShort => 'unsupported host';

  @override
  String get serverFailureBinaryNotFound => 'llama-server was not found';

  @override
  String get serverFailureBinaryNotExecutable =>
      'llama-server cannot be executed';

  @override
  String get serverFailureUnsupportedVersion => 'Unsupported llama.cpp build';

  @override
  String get serverFailurePortInUse => 'The port is already in use';

  @override
  String get serverFailureModelNotFound => 'The model file was not found';

  @override
  String get serverFailureInvalidConfig => 'The configuration is invalid';

  @override
  String get serverFailureStartupTimeout => 'The server did not start in time';

  @override
  String get serverFailureProcessExited => 'llama-server exited';

  @override
  String get serverFailureHealthCheckFailed => 'The health check failed';

  @override
  String get serverFailureHttpError => 'The HTTP request failed';

  @override
  String get serverFailureStateUnreadable =>
      'The server state could not be read';

  @override
  String get serverFailureConfigLoadFailed =>
      'Could not load the server configuration';

  @override
  String get serverFailureConfigSaveFailed =>
      'Could not save the server configuration';

  @override
  String get serverFailureBinaryInspectionFailed =>
      'Could not inspect llama-server';

  @override
  String get serverFailureStartFailed => 'Could not start llama-server';

  @override
  String get serverFailureStopFailed => 'Could not stop llama-server';

  @override
  String get serverFailureStreamEnded =>
      'The server controller closed its stream';

  @override
  String get serverFailureExternalRun =>
      'The server was started outside this app';

  @override
  String get serverFailureUnknown => 'Unexpected error';

  @override
  String get inferenceFailureEngineUnavailable =>
      'No inference engine is available';

  @override
  String get inferenceFailureModelNotFound => 'The model file was not found';

  @override
  String get inferenceFailureInvalidParams => 'The parameters are invalid';

  @override
  String get inferenceFailureEngineBusy => 'The engine is busy';

  @override
  String get inferenceFailureCancelled => 'The generation was cancelled';

  @override
  String get inferenceFailureNativeError =>
      'The native engine reported an error';

  @override
  String get inferenceFailureLibraryNotFound =>
      'No llama.cpp library was found';

  @override
  String get inferenceFailureLibraryVersionMismatch =>
      'The llama.cpp library is not the pinned version';

  @override
  String get inferenceFailureParamsLoadFailed =>
      'Could not load the stored parameters';

  @override
  String get inferenceFailureParamsSaveFailed =>
      'Could not save the parameters';

  @override
  String get inferenceFailureModelPathRequired => 'A model path is required';

  @override
  String get inferenceFailureModelLoadFailed => 'Could not load the model';

  @override
  String get inferenceFailurePromptRequired => 'A prompt is required';

  @override
  String get inferenceFailureModelNotReady => 'The model is not ready';

  @override
  String get inferenceFailureCancelFailed => 'Could not cancel the generation';

  @override
  String get inferenceFailureUnloadFailed => 'Could not unload the model';

  @override
  String get inferenceFailureStreamEnded =>
      'The engine closed the stream without a result';

  @override
  String get inferenceFailureUnknown => 'Unexpected error';

  @override
  String get runtimeErrorStatusReadFailed =>
      'Could not read the runtime status';

  @override
  String get runtimeErrorUnavailableOnHost =>
      'This backend is not available on this host';

  @override
  String get runtimeErrorInstallFailed => 'The install failed';

  @override
  String get runtimeErrorActionFailed => 'The action failed';

  @override
  String get runtimeNoticeCancelling => 'Cancelling the download…';

  @override
  String get runtimeNoticeInstallCancelled => 'The install was cancelled.';

  @override
  String runtimeNoticeInstalled(String backend) {
    return 'Installed $backend.';
  }

  @override
  String runtimeNoticeSelected(String id) {
    return 'Selected $id.';
  }

  @override
  String runtimeNoticeRemoved(String id) {
    return 'Removed $id.';
  }

  @override
  String get runtimeGateNotInstalled => 'not installed';

  @override
  String get runtimeGateExact => 'exact';

  @override
  String get runtimeGateAttested => 'attested';

  @override
  String get runtimeGateUnknown => 'unknown';

  @override
  String get runtimeGateRejected => 'rejected';
}
