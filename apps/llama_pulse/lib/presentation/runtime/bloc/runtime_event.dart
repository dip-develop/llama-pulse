import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Commands accepted by the runtime bloc.
///
/// Events are transient UI commands: they never cross the isolate boundary and
/// are never persisted, so they stay plain immutable classes instead of
/// `built_value` types.
sealed class RuntimeEvent {
  const RuntimeEvent();
}

/// Loads the host detection and the installed runtime index.
final class RuntimeStarted extends RuntimeEvent {
  const RuntimeStarted();
}

/// Re-reads the host detection and the installed runtime index.
final class RuntimeRefreshed extends RuntimeEvent {
  const RuntimeRefreshed();
}

/// Downloads and installs [backend] with the pinned release.
final class RuntimeInstallRequested extends RuntimeEvent {
  const RuntimeInstallRequested(this.backend, {this.force = false});

  /// Backend to install.
  final RuntimeBackend backend;

  /// Whether an existing install may be replaced.
  final bool force;
}

/// Cancels the running install.
final class RuntimeCancelRequested extends RuntimeEvent {
  const RuntimeCancelRequested();
}

/// Marks [tag]/[backend] as the runtime the loaders prefer.
final class RuntimeSelectRequested extends RuntimeEvent {
  const RuntimeSelectRequested(this.tag, this.backend);

  /// Release tag of the install.
  final String tag;

  /// Backend of the install.
  final RuntimeBackend backend;
}

/// Deletes [tag]/[backend] and drops it from the index.
final class RuntimeRemoveRequested extends RuntimeEvent {
  const RuntimeRemoveRequested(this.tag, this.backend);

  /// Release tag of the install.
  final String tag;

  /// Backend of the install.
  final RuntimeBackend backend;
}

/// Internal plumbing: the downloader reported progress.
///
/// UI code never adds it.
final class RuntimeProgressReceived extends RuntimeEvent {
  const RuntimeProgressReceived(this.progress);

  /// Bytes received so far and the expected total.
  final RuntimeProgress progress;
}

/// Internal plumbing: a status read finished.
///
/// UI code never adds it.
final class RuntimeStatusReceived extends RuntimeEvent {
  const RuntimeStatusReceived({this.status, this.error});

  /// The refreshed status, or null when the read failed.
  final RuntimeStatus? status;

  /// Why the read failed, or null.
  final String? error;
}

/// Internal plumbing: an install finished.
///
/// UI code never adds it.
final class RuntimeInstallCompleted extends RuntimeEvent {
  const RuntimeInstallCompleted({this.error, this.cancelled = false});

  /// Why the install failed, or null on success.
  final String? error;

  /// Whether the user cancelled the download.
  final bool cancelled;
}

/// Internal plumbing: a select or remove finished.
///
/// UI code never adds it.
final class RuntimeActionCompleted extends RuntimeEvent {
  const RuntimeActionCompleted({this.error, this.notice});

  /// Why the action failed, or null on success.
  final String? error;

  /// Summary of the successful action.
  final String? notice;
}
