import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LlamaPulse'**
  String get appTitle;

  /// No description provided for @homeTitleServer.
  ///
  /// In en, this message translates to:
  /// **'LlamaPulse — Server'**
  String get homeTitleServer;

  /// No description provided for @homeTitleChat.
  ///
  /// In en, this message translates to:
  /// **'LlamaPulse — Chat'**
  String get homeTitleChat;

  /// No description provided for @homeTitleRuntime.
  ///
  /// In en, this message translates to:
  /// **'LlamaPulse — Runtime'**
  String get homeTitleRuntime;

  /// No description provided for @navServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get navServer;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navRuntime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get navRuntime;

  /// No description provided for @navChatExperimental.
  ///
  /// In en, this message translates to:
  /// **'Chat (experimental)'**
  String get navChatExperimental;

  /// No description provided for @chatExperimentalBanner.
  ///
  /// In en, this message translates to:
  /// **'Experimental — embedded chat. The server is the primary path.'**
  String get chatExperimentalBanner;

  /// No description provided for @serverDemoBanner.
  ///
  /// In en, this message translates to:
  /// **'Demo server — no llama-server process is started.'**
  String get serverDemoBanner;

  /// No description provided for @serverStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverStatusTitle;

  /// No description provided for @serverStatusHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get serverStatusHealth;

  /// No description provided for @serverStatusSupervisorPid.
  ///
  /// In en, this message translates to:
  /// **'Supervisor pid'**
  String get serverStatusSupervisorPid;

  /// No description provided for @serverStatusServerPid.
  ///
  /// In en, this message translates to:
  /// **'Server pid'**
  String get serverStatusServerPid;

  /// No description provided for @serverStatusModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get serverStatusModel;

  /// No description provided for @serverStatusBinary.
  ///
  /// In en, this message translates to:
  /// **'Binary'**
  String get serverStatusBinary;

  /// No description provided for @serverStatusBinaryNotLocated.
  ///
  /// In en, this message translates to:
  /// **'not located'**
  String get serverStatusBinaryNotLocated;

  /// No description provided for @serverStatusVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get serverStatusVersion;

  /// No description provided for @serverStatusExternalRun.
  ///
  /// In en, this message translates to:
  /// **'Started outside this app — stop it with llamapulse stop.'**
  String get serverStatusExternalRun;

  /// No description provided for @serverStatusUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get serverStatusUptime;

  /// No description provided for @serverStatusLastExitCode.
  ///
  /// In en, this message translates to:
  /// **'Last exit code'**
  String get serverStatusLastExitCode;

  /// No description provided for @serverStatusLastFailure.
  ///
  /// In en, this message translates to:
  /// **'Last failure'**
  String get serverStatusLastFailure;

  /// No description provided for @serverStatusStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get serverStatusStart;

  /// No description provided for @serverStatusStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get serverStatusStop;

  /// No description provided for @serverPhaseRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get serverPhaseRunning;

  /// No description provided for @serverPhaseStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get serverPhaseStarting;

  /// No description provided for @serverPhaseStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get serverPhaseStopping;

  /// No description provided for @serverPhaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get serverPhaseFailed;

  /// No description provided for @serverPhaseStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get serverPhaseStopped;

  /// No description provided for @serverEndpointTitle.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get serverEndpointTitle;

  /// No description provided for @serverEndpointCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get serverEndpointCopy;

  /// No description provided for @serverEndpointTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get serverEndpointTesting;

  /// No description provided for @serverEndpointTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get serverEndpointTestConnection;

  /// No description provided for @serverEndpointConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected ({latencyMs} ms)'**
  String serverEndpointConnected(int latencyMs);

  /// No description provided for @serverMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get serverMetricsTitle;

  /// No description provided for @serverMetricsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Metrics appear once the server is running.'**
  String get serverMetricsEmpty;

  /// No description provided for @serverMetricsGeneration.
  ///
  /// In en, this message translates to:
  /// **'Generation'**
  String get serverMetricsGeneration;

  /// No description provided for @serverMetricsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get serverMetricsPrompt;

  /// No description provided for @serverMetricsActiveSlots.
  ///
  /// In en, this message translates to:
  /// **'Active slots'**
  String get serverMetricsActiveSlots;

  /// No description provided for @serverMetricsRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get serverMetricsRequests;

  /// No description provided for @serverMetricsRequestsValue.
  ///
  /// In en, this message translates to:
  /// **'{processing} processing · {deferred} deferred'**
  String serverMetricsRequestsValue(int processing, int deferred);

  /// No description provided for @serverMetricsPredictedTokens.
  ///
  /// In en, this message translates to:
  /// **'Predicted tokens'**
  String get serverMetricsPredictedTokens;

  /// No description provided for @serverMetricsContextUsage.
  ///
  /// In en, this message translates to:
  /// **'Context usage'**
  String get serverMetricsContextUsage;

  /// No description provided for @serverMetricsContextNotExposed.
  ///
  /// In en, this message translates to:
  /// **'not exposed'**
  String get serverMetricsContextNotExposed;

  /// No description provided for @serverLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get serverLogTitle;

  /// No description provided for @serverLogClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get serverLogClear;

  /// No description provided for @serverLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No log lines yet.'**
  String get serverLogEmpty;

  /// No description provided for @serverConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Server configuration'**
  String get serverConfigTitle;

  /// No description provided for @serverConfigUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get serverConfigUnsavedChanges;

  /// No description provided for @serverConfigApplyOnNextStart.
  ///
  /// In en, this message translates to:
  /// **'Changes apply on the next start.'**
  String get serverConfigApplyOnNextStart;

  /// No description provided for @serverConfigModelPath.
  ///
  /// In en, this message translates to:
  /// **'Model path'**
  String get serverConfigModelPath;

  /// No description provided for @modelPathExample.
  ///
  /// In en, this message translates to:
  /// **'/models/model.gguf'**
  String get modelPathExample;

  /// No description provided for @serverConfigBinaryPath.
  ///
  /// In en, this message translates to:
  /// **'llama-server binary'**
  String get serverConfigBinaryPath;

  /// No description provided for @serverConfigBinaryPathHint.
  ///
  /// In en, this message translates to:
  /// **'auto-detected when empty'**
  String get serverConfigBinaryPathHint;

  /// No description provided for @serverConfigHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get serverConfigHost;

  /// No description provided for @serverConfigPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get serverConfigPort;

  /// No description provided for @serverConfigContextSize.
  ///
  /// In en, this message translates to:
  /// **'Context size'**
  String get serverConfigContextSize;

  /// No description provided for @serverConfigThreads.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get serverConfigThreads;

  /// No description provided for @serverConfigGpuLayers.
  ///
  /// In en, this message translates to:
  /// **'GPU layers'**
  String get serverConfigGpuLayers;

  /// No description provided for @serverConfigParallelSlots.
  ///
  /// In en, this message translates to:
  /// **'Parallel slots'**
  String get serverConfigParallelSlots;

  /// No description provided for @serverConfigModelAlias.
  ///
  /// In en, this message translates to:
  /// **'Model alias'**
  String get serverConfigModelAlias;

  /// No description provided for @serverConfigApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get serverConfigApiKey;

  /// No description provided for @serverConfigApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'empty disables authentication'**
  String get serverConfigApiKeyHint;

  /// No description provided for @serverConfigReveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get serverConfigReveal;

  /// No description provided for @serverConfigHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get serverConfigHide;

  /// No description provided for @serverConfigFlashAttention.
  ///
  /// In en, this message translates to:
  /// **'Flash attention'**
  String get serverConfigFlashAttention;

  /// No description provided for @serverConfigMlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lock the model in RAM'**
  String get serverConfigMlockSubtitle;

  /// No description provided for @serverConfigMmapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Memory-map the model file'**
  String get serverConfigMmapSubtitle;

  /// No description provided for @serverConfigExtraArgs.
  ///
  /// In en, this message translates to:
  /// **'Extra arguments'**
  String get serverConfigExtraArgs;

  /// No description provided for @serverConfigExtraArgsHint.
  ///
  /// In en, this message translates to:
  /// **'one argument per line'**
  String get serverConfigExtraArgsHint;

  /// No description provided for @serverConfigStartupTimeout.
  ///
  /// In en, this message translates to:
  /// **'Startup timeout (s)'**
  String get serverConfigStartupTimeout;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @reloadAction.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reloadAction;

  /// No description provided for @browseAction.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browseAction;

  /// No description provided for @paramsTitleServer.
  ///
  /// In en, this message translates to:
  /// **'Server parameters'**
  String get paramsTitleServer;

  /// No description provided for @paramsSubtitleServer.
  ///
  /// In en, this message translates to:
  /// **'Every other llama-server flag. The essentials stay in the form above and are saved with them.'**
  String get paramsSubtitleServer;

  /// No description provided for @paramsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search parameters'**
  String get paramsSearchHint;

  /// No description provided for @paramsModifiedOnly.
  ///
  /// In en, this message translates to:
  /// **'Modified only'**
  String get paramsModifiedOnly;

  /// No description provided for @paramsExpandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get paramsExpandAll;

  /// No description provided for @paramsCollapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get paramsCollapseAll;

  /// No description provided for @paramsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No parameters match'**
  String get paramsEmpty;

  /// No description provided for @paramsCount.
  ///
  /// In en, this message translates to:
  /// **'{modified} modified / {available} available'**
  String paramsCount(int modified, int available);

  /// No description provided for @paramsUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get paramsUndo;

  /// No description provided for @paramsResetParameter.
  ///
  /// In en, this message translates to:
  /// **'Reset {name}'**
  String paramsResetParameter(String name);

  /// No description provided for @paramsResetGroup.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Reset 1 parameter in {group}} other{Reset {count} parameters in {group}}}'**
  String paramsResetGroup(int count, String group);

  /// No description provided for @paramsResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get paramsResetToDefault;

  /// No description provided for @paramsEffectiveValue.
  ///
  /// In en, this message translates to:
  /// **'Effective value: {value}'**
  String paramsEffectiveValue(String value);

  /// No description provided for @paramsUseReplacement.
  ///
  /// In en, this message translates to:
  /// **'Use {replacement} instead.'**
  String paramsUseReplacement(String replacement);

  /// No description provided for @paramsResetGroupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset this group'**
  String get paramsResetGroupTooltip;

  /// No description provided for @paramsDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get paramsDefaultHint;

  /// No description provided for @paramsManagedBy.
  ///
  /// In en, this message translates to:
  /// **'Managed by {owner}.'**
  String paramsManagedBy(String owner);

  /// No description provided for @paramsUnsupportedReason.
  ///
  /// In en, this message translates to:
  /// **'llama-server does not accept this parameter.'**
  String get paramsUnsupportedReason;

  /// No description provided for @paramsRemovedReason.
  ///
  /// In en, this message translates to:
  /// **'llama.cpp removed this parameter.'**
  String get paramsRemovedReason;

  /// No description provided for @paramsSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Select {name}'**
  String paramsSelectFile(String name);

  /// No description provided for @paramTooltipNegated.
  ///
  /// In en, this message translates to:
  /// **'Negated form: {flag}'**
  String paramTooltipNegated(String flag);

  /// No description provided for @paramTooltipType.
  ///
  /// In en, this message translates to:
  /// **'Type: {valueType}'**
  String paramTooltipType(String valueType);

  /// No description provided for @paramTooltipDefault.
  ///
  /// In en, this message translates to:
  /// **'Default: {value}'**
  String paramTooltipDefault(String value);

  /// No description provided for @paramTooltipDynamic.
  ///
  /// In en, this message translates to:
  /// **'dynamic'**
  String get paramTooltipDynamic;

  /// No description provided for @paramTooltipRange.
  ///
  /// In en, this message translates to:
  /// **'Range: {range}'**
  String paramTooltipRange(String range);

  /// No description provided for @paramTooltipEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment: {variable}'**
  String paramTooltipEnvironment(String variable);

  /// No description provided for @paramTooltipWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: {warning}'**
  String paramTooltipWarning(String warning);

  /// No description provided for @paramTooltipNote.
  ///
  /// In en, this message translates to:
  /// **'Note: {reason}'**
  String paramTooltipNote(String reason);

  /// No description provided for @paramTooltipReplacedBy.
  ///
  /// In en, this message translates to:
  /// **'Replaced by: {replacement}'**
  String paramTooltipReplacedBy(String replacement);

  /// No description provided for @paramTypeTwoValues.
  ///
  /// In en, this message translates to:
  /// **'two values on separate lines'**
  String get paramTypeTwoValues;

  /// No description provided for @paramTypeSwitch.
  ///
  /// In en, this message translates to:
  /// **'switch'**
  String get paramTypeSwitch;

  /// No description provided for @paramTypeInteger.
  ///
  /// In en, this message translates to:
  /// **'integer'**
  String get paramTypeInteger;

  /// No description provided for @paramTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'number'**
  String get paramTypeNumber;

  /// No description provided for @paramTypeOneOf.
  ///
  /// In en, this message translates to:
  /// **'one of: {values}'**
  String paramTypeOneOf(String values);

  /// No description provided for @paramTypePath.
  ///
  /// In en, this message translates to:
  /// **'path'**
  String get paramTypePath;

  /// No description provided for @paramTypeText.
  ///
  /// In en, this message translates to:
  /// **'text'**
  String get paramTypeText;

  /// No description provided for @paramTypeOnePerLine.
  ///
  /// In en, this message translates to:
  /// **'{valueType}, one per line'**
  String paramTypeOnePerLine(String valueType);

  /// No description provided for @paramTypeCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'{valueType}, comma separated'**
  String paramTypeCommaSeparated(String valueType);

  /// No description provided for @paramRangeStep.
  ///
  /// In en, this message translates to:
  /// **'step {step}'**
  String paramRangeStep(String step);

  /// No description provided for @paramRangeSteps.
  ///
  /// In en, this message translates to:
  /// **'{bounds} in steps of {step}'**
  String paramRangeSteps(String bounds, String step);

  /// No description provided for @chatDemoBanner.
  ///
  /// In en, this message translates to:
  /// **'Demo engine — output is synthetic.'**
  String get chatDemoBanner;

  /// No description provided for @chatStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get chatStatusIdle;

  /// No description provided for @chatStatusLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Loading model'**
  String get chatStatusLoadingModel;

  /// No description provided for @chatStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get chatStatusReady;

  /// No description provided for @chatStatusGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating'**
  String get chatStatusGenerating;

  /// No description provided for @chatStatusCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling'**
  String get chatStatusCancelling;

  /// No description provided for @chatStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get chatStatusError;

  /// No description provided for @chatPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get chatPromptLabel;

  /// No description provided for @chatPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the model something…'**
  String get chatPromptHint;

  /// No description provided for @chatGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get chatGenerate;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @unloadAction.
  ///
  /// In en, this message translates to:
  /// **'Unload'**
  String get unloadAction;

  /// No description provided for @chatConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get chatConversationTitle;

  /// No description provided for @chatClearConversation.
  ///
  /// In en, this message translates to:
  /// **'Clear conversation'**
  String get chatClearConversation;

  /// No description provided for @chatNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.'**
  String get chatNoMessages;

  /// No description provided for @chatRoleYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatRoleYou;

  /// No description provided for @chatRoleAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get chatRoleAssistant;

  /// No description provided for @chatRoleTool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get chatRoleTool;

  /// No description provided for @chatMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get chatMetricsTitle;

  /// No description provided for @chatMetricsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Metrics appear here after a generation.'**
  String get chatMetricsEmpty;

  /// No description provided for @chatMetricsTokensPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Tokens/sec'**
  String get chatMetricsTokensPerSecond;

  /// No description provided for @chatMetricsPromptEval.
  ///
  /// In en, this message translates to:
  /// **'Prompt eval'**
  String get chatMetricsPromptEval;

  /// No description provided for @chatMetricsGeneratedTokens.
  ///
  /// In en, this message translates to:
  /// **'Generated tokens'**
  String get chatMetricsGeneratedTokens;

  /// No description provided for @chatMetricsPromptTokens.
  ///
  /// In en, this message translates to:
  /// **'Prompt tokens'**
  String get chatMetricsPromptTokens;

  /// No description provided for @chatMetricsTimeToFirstToken.
  ///
  /// In en, this message translates to:
  /// **'Time to first token'**
  String get chatMetricsTimeToFirstToken;

  /// No description provided for @chatMetricsReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get chatMetricsReports;

  /// No description provided for @chatMetricsReportsValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 sample} other{{count} samples}}'**
  String chatMetricsReportsValue(int count);

  /// No description provided for @chatModelParamsTitle.
  ///
  /// In en, this message translates to:
  /// **'Model parameters'**
  String get chatModelParamsTitle;

  /// No description provided for @chatModelParamsHint.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to the next load.'**
  String get chatModelParamsHint;

  /// No description provided for @chatModelPath.
  ///
  /// In en, this message translates to:
  /// **'Model path'**
  String get chatModelPath;

  /// No description provided for @chatContextSize.
  ///
  /// In en, this message translates to:
  /// **'Context size'**
  String get chatContextSize;

  /// No description provided for @chatGpuLayers.
  ///
  /// In en, this message translates to:
  /// **'GPU layers'**
  String get chatGpuLayers;

  /// No description provided for @chatThreads.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get chatThreads;

  /// No description provided for @chatTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get chatTemperature;

  /// No description provided for @chatTopP.
  ///
  /// In en, this message translates to:
  /// **'Top-p'**
  String get chatTopP;

  /// No description provided for @chatTopK.
  ///
  /// In en, this message translates to:
  /// **'Top-k'**
  String get chatTopK;

  /// No description provided for @chatMaxTokens.
  ///
  /// In en, this message translates to:
  /// **'Max tokens'**
  String get chatMaxTokens;

  /// No description provided for @chatTemplateLabel.
  ///
  /// In en, this message translates to:
  /// **'Chat template'**
  String get chatTemplateLabel;

  /// No description provided for @chatTemplateHint.
  ///
  /// In en, this message translates to:
  /// **'Model default, a built-in name, or \"none\"'**
  String get chatTemplateHint;

  /// No description provided for @chatSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'System prompt'**
  String get chatSystemPrompt;

  /// No description provided for @chatSystemPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Prepended as the system message of each chat request'**
  String get chatSystemPromptHint;

  /// No description provided for @chatApplyTemplate.
  ///
  /// In en, this message translates to:
  /// **'Apply chat template'**
  String get chatApplyTemplate;

  /// No description provided for @chatApplyTemplateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off sends the raw prompt even when a template is set.'**
  String get chatApplyTemplateSubtitle;

  /// No description provided for @chatLoadModel.
  ///
  /// In en, this message translates to:
  /// **'Load model'**
  String get chatLoadModel;

  /// No description provided for @chatParamsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat parameters'**
  String get chatParamsTitle;

  /// No description provided for @chatParamsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every other llama-cli flag for this session. The essentials stay in the form above and are saved with them.'**
  String get chatParamsSubtitle;

  /// No description provided for @chatManagedGroupName.
  ///
  /// In en, this message translates to:
  /// **'Set in the essentials form'**
  String get chatManagedGroupName;

  /// No description provided for @chatServerOnlyGroupName.
  ///
  /// In en, this message translates to:
  /// **'Not available in the embedded engine'**
  String get chatServerOnlyGroupName;

  /// No description provided for @chatServerOnlyReason.
  ///
  /// In en, this message translates to:
  /// **'embedded engine cannot honor this parameter yet'**
  String get chatServerOnlyReason;

  /// No description provided for @chatManagedGroupReason.
  ///
  /// In en, this message translates to:
  /// **'Set by the essentials form above; edit it there and save once for both.'**
  String get chatManagedGroupReason;

  /// No description provided for @runtimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get runtimeTitle;

  /// No description provided for @runtimeRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get runtimeRefresh;

  /// No description provided for @runtimeDetectingHost.
  ///
  /// In en, this message translates to:
  /// **'Detecting the host…'**
  String get runtimeDetectingHost;

  /// No description provided for @runtimeDetecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting…'**
  String get runtimeDetecting;

  /// No description provided for @runtimeRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get runtimeRecommended;

  /// No description provided for @runtimeRecommendedBackend.
  ///
  /// In en, this message translates to:
  /// **'Recommended: {backend}'**
  String runtimeRecommendedBackend(String backend);

  /// No description provided for @runtimeRecommendedReason.
  ///
  /// In en, this message translates to:
  /// **'Recommended: {backend} — {reason}'**
  String runtimeRecommendedReason(String backend, String reason);

  /// No description provided for @runtimeUnsupportedHost.
  ///
  /// In en, this message translates to:
  /// **'The pinned release has no archive for this host.'**
  String get runtimeUnsupportedHost;

  /// No description provided for @runtimeInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing {backend}'**
  String runtimeInstalling(String backend);

  /// No description provided for @runtimeInstallingProgress.
  ///
  /// In en, this message translates to:
  /// **'Installing {backend}: {percent}%'**
  String runtimeInstallingProgress(String backend, int percent);

  /// No description provided for @runtimeProgressValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}% · {received} of {total}'**
  String runtimeProgressValue(int percent, String received, String total);

  /// No description provided for @runtimeProgressRate.
  ///
  /// In en, this message translates to:
  /// **'{rate}/s'**
  String runtimeProgressRate(String rate);

  /// No description provided for @runtimeAvailableBackends.
  ///
  /// In en, this message translates to:
  /// **'Available backends'**
  String get runtimeAvailableBackends;

  /// No description provided for @runtimeNoBackendAvailable.
  ///
  /// In en, this message translates to:
  /// **'No backend is available for this host.'**
  String get runtimeNoBackendAvailable;

  /// No description provided for @runtimeInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get runtimeInstalled;

  /// No description provided for @runtimeInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get runtimeInstall;

  /// No description provided for @runtimeReinstall.
  ///
  /// In en, this message translates to:
  /// **'Reinstall'**
  String get runtimeReinstall;

  /// No description provided for @runtimeSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get runtimeSelect;

  /// No description provided for @runtimeSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get runtimeSelected;

  /// No description provided for @runtimeRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get runtimeRemove;

  /// No description provided for @runtimeRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {id}?'**
  String runtimeRemoveTitle(String id);

  /// No description provided for @runtimeRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'The runtime directory and its manifest are deleted.'**
  String get runtimeRemoveMessage;

  /// No description provided for @runtimeNoRuntimesInstalled.
  ///
  /// In en, this message translates to:
  /// **'No runtimes installed yet.'**
  String get runtimeNoRuntimesInstalled;

  /// No description provided for @runtimeGateLabel.
  ///
  /// In en, this message translates to:
  /// **'Gate'**
  String get runtimeGateLabel;

  /// No description provided for @runtimeGateValue.
  ///
  /// In en, this message translates to:
  /// **'{verdict} — {reason}'**
  String runtimeGateValue(String verdict, String reason);

  /// No description provided for @runtimeGateSummary.
  ///
  /// In en, this message translates to:
  /// **'Gate: {verdict} — {reason}'**
  String runtimeGateSummary(String verdict, String reason);

  /// No description provided for @runtimeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable: {reason}'**
  String runtimeUnavailable(String reason);

  /// No description provided for @runtimeHardware.
  ///
  /// In en, this message translates to:
  /// **'Detected hardware'**
  String get runtimeHardware;

  /// No description provided for @runtimeNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get runtimeNone;

  /// No description provided for @runtimeHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'LlamaPulse runs a pinned llama.cpp build; the detected hardware decides which backends it can install.'**
  String get runtimeHeaderSubtitle;

  /// No description provided for @runtimeManagedTitle.
  ///
  /// In en, this message translates to:
  /// **'Managed runtimes'**
  String get runtimeManagedTitle;

  /// No description provided for @runtimeManagedNote.
  ///
  /// In en, this message translates to:
  /// **'Installs a pinned llama.cpp build. A system-wide llama.cpp is not used.'**
  String get runtimeManagedNote;

  /// No description provided for @runtimeInstallRuntime.
  ///
  /// In en, this message translates to:
  /// **'Install runtime'**
  String get runtimeInstallRuntime;

  /// No description provided for @runtimeInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Install {backend}'**
  String runtimeInstallTitle(String backend);

  /// No description provided for @runtimeDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get runtimeDownload;

  /// No description provided for @runtimeCudaRuntime.
  ///
  /// In en, this message translates to:
  /// **'CUDA runtime'**
  String get runtimeCudaRuntime;

  /// No description provided for @runtimePlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get runtimePlatform;

  /// No description provided for @runtimeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'unsupported'**
  String get runtimeUnsupported;

  /// No description provided for @runtimeDriverRequirement.
  ///
  /// In en, this message translates to:
  /// **'Driver requirement: {requirement}'**
  String runtimeDriverRequirement(String requirement);

  /// No description provided for @runtimeCudaNote.
  ///
  /// In en, this message translates to:
  /// **'The CUDA runtime is a second archive bundled only when you install a CUDA backend.'**
  String get runtimeCudaNote;

  /// No description provided for @runtimeUnknownSize.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get runtimeUnknownSize;

  /// No description provided for @runtimeNoGpuDetected.
  ///
  /// In en, this message translates to:
  /// **'no GPU detected'**
  String get runtimeNoGpuDetected;

  /// No description provided for @runtimeUnsupportedHostShort.
  ///
  /// In en, this message translates to:
  /// **'unsupported host'**
  String get runtimeUnsupportedHostShort;

  /// No description provided for @serverFailureBinaryNotFound.
  ///
  /// In en, this message translates to:
  /// **'llama-server was not found'**
  String get serverFailureBinaryNotFound;

  /// No description provided for @serverFailureBinaryNotExecutable.
  ///
  /// In en, this message translates to:
  /// **'llama-server cannot be executed'**
  String get serverFailureBinaryNotExecutable;

  /// No description provided for @serverFailureUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'Unsupported llama.cpp build'**
  String get serverFailureUnsupportedVersion;

  /// No description provided for @serverFailurePortInUse.
  ///
  /// In en, this message translates to:
  /// **'The port is already in use'**
  String get serverFailurePortInUse;

  /// No description provided for @serverFailureModelNotFound.
  ///
  /// In en, this message translates to:
  /// **'The model file was not found'**
  String get serverFailureModelNotFound;

  /// No description provided for @serverFailureInvalidConfig.
  ///
  /// In en, this message translates to:
  /// **'The configuration is invalid'**
  String get serverFailureInvalidConfig;

  /// No description provided for @serverFailureStartupTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server did not start in time'**
  String get serverFailureStartupTimeout;

  /// No description provided for @serverFailureProcessExited.
  ///
  /// In en, this message translates to:
  /// **'llama-server exited'**
  String get serverFailureProcessExited;

  /// No description provided for @serverFailureHealthCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'The health check failed'**
  String get serverFailureHealthCheckFailed;

  /// No description provided for @serverFailureHttpError.
  ///
  /// In en, this message translates to:
  /// **'The HTTP request failed'**
  String get serverFailureHttpError;

  /// No description provided for @serverFailureStateUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The server state could not be read'**
  String get serverFailureStateUnreadable;

  /// No description provided for @serverFailureConfigLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the server configuration'**
  String get serverFailureConfigLoadFailed;

  /// No description provided for @serverFailureConfigSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the server configuration'**
  String get serverFailureConfigSaveFailed;

  /// No description provided for @serverFailureBinaryInspectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not inspect llama-server'**
  String get serverFailureBinaryInspectionFailed;

  /// No description provided for @serverFailureStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start llama-server'**
  String get serverFailureStartFailed;

  /// No description provided for @serverFailureStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not stop llama-server'**
  String get serverFailureStopFailed;

  /// No description provided for @serverFailureStreamEnded.
  ///
  /// In en, this message translates to:
  /// **'The server controller closed its stream'**
  String get serverFailureStreamEnded;

  /// No description provided for @serverFailureExternalRun.
  ///
  /// In en, this message translates to:
  /// **'The server was started outside this app'**
  String get serverFailureExternalRun;

  /// No description provided for @serverFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error'**
  String get serverFailureUnknown;

  /// No description provided for @inferenceFailureEngineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No inference engine is available'**
  String get inferenceFailureEngineUnavailable;

  /// No description provided for @inferenceFailureModelNotFound.
  ///
  /// In en, this message translates to:
  /// **'The model file was not found'**
  String get inferenceFailureModelNotFound;

  /// No description provided for @inferenceFailureInvalidParams.
  ///
  /// In en, this message translates to:
  /// **'The parameters are invalid'**
  String get inferenceFailureInvalidParams;

  /// No description provided for @inferenceFailureEngineBusy.
  ///
  /// In en, this message translates to:
  /// **'The engine is busy'**
  String get inferenceFailureEngineBusy;

  /// No description provided for @inferenceFailureCancelled.
  ///
  /// In en, this message translates to:
  /// **'The generation was cancelled'**
  String get inferenceFailureCancelled;

  /// No description provided for @inferenceFailureNativeError.
  ///
  /// In en, this message translates to:
  /// **'The native engine reported an error'**
  String get inferenceFailureNativeError;

  /// No description provided for @inferenceFailureLibraryNotFound.
  ///
  /// In en, this message translates to:
  /// **'No llama.cpp library was found'**
  String get inferenceFailureLibraryNotFound;

  /// No description provided for @inferenceFailureLibraryVersionMismatch.
  ///
  /// In en, this message translates to:
  /// **'The llama.cpp library is not the pinned version'**
  String get inferenceFailureLibraryVersionMismatch;

  /// No description provided for @inferenceFailureParamsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the stored parameters'**
  String get inferenceFailureParamsLoadFailed;

  /// No description provided for @inferenceFailureParamsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the parameters'**
  String get inferenceFailureParamsSaveFailed;

  /// No description provided for @inferenceFailureModelPathRequired.
  ///
  /// In en, this message translates to:
  /// **'A model path is required'**
  String get inferenceFailureModelPathRequired;

  /// No description provided for @inferenceFailureModelLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the model'**
  String get inferenceFailureModelLoadFailed;

  /// No description provided for @inferenceFailurePromptRequired.
  ///
  /// In en, this message translates to:
  /// **'A prompt is required'**
  String get inferenceFailurePromptRequired;

  /// No description provided for @inferenceFailureModelNotReady.
  ///
  /// In en, this message translates to:
  /// **'The model is not ready'**
  String get inferenceFailureModelNotReady;

  /// No description provided for @inferenceFailureCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel the generation'**
  String get inferenceFailureCancelFailed;

  /// No description provided for @inferenceFailureUnloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not unload the model'**
  String get inferenceFailureUnloadFailed;

  /// No description provided for @inferenceFailureStreamEnded.
  ///
  /// In en, this message translates to:
  /// **'The engine closed the stream without a result'**
  String get inferenceFailureStreamEnded;

  /// No description provided for @inferenceFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error'**
  String get inferenceFailureUnknown;

  /// No description provided for @runtimeErrorStatusReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the runtime status'**
  String get runtimeErrorStatusReadFailed;

  /// No description provided for @runtimeErrorUnavailableOnHost.
  ///
  /// In en, this message translates to:
  /// **'This backend is not available on this host'**
  String get runtimeErrorUnavailableOnHost;

  /// No description provided for @runtimeErrorInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'The install failed'**
  String get runtimeErrorInstallFailed;

  /// No description provided for @runtimeErrorActionFailed.
  ///
  /// In en, this message translates to:
  /// **'The action failed'**
  String get runtimeErrorActionFailed;

  /// No description provided for @runtimeNoticeCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling the download…'**
  String get runtimeNoticeCancelling;

  /// No description provided for @runtimeNoticeInstallCancelled.
  ///
  /// In en, this message translates to:
  /// **'The install was cancelled.'**
  String get runtimeNoticeInstallCancelled;

  /// No description provided for @runtimeNoticeInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed {backend}.'**
  String runtimeNoticeInstalled(String backend);

  /// No description provided for @runtimeNoticeSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected {id}.'**
  String runtimeNoticeSelected(String id);

  /// No description provided for @runtimeNoticeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {id}.'**
  String runtimeNoticeRemoved(String id);

  /// No description provided for @runtimeGateNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'not installed'**
  String get runtimeGateNotInstalled;

  /// No description provided for @runtimeGateExact.
  ///
  /// In en, this message translates to:
  /// **'exact'**
  String get runtimeGateExact;

  /// No description provided for @runtimeGateAttested.
  ///
  /// In en, this message translates to:
  /// **'attested'**
  String get runtimeGateAttested;

  /// No description provided for @runtimeGateUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get runtimeGateUnknown;

  /// No description provided for @runtimeGateRejected.
  ///
  /// In en, this message translates to:
  /// **'rejected'**
  String get runtimeGateRejected;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
