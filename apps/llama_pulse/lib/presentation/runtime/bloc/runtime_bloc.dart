import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import 'runtime_event.dart';
import 'runtime_messages.dart';
import 'runtime_state.dart';

/// Drives the Runtime tab and the dashboard card.
///
/// The bloc owns one detection/status read and one install at a time. The
/// installer is shared through DI; a cancelled install releases its token and
/// the staging tree is removed by the installer itself.
class RuntimeBloc extends Bloc<RuntimeEvent, RuntimeState> {
  /// Creates the bloc over the status reader and the installer.
  RuntimeBloc(this._reader, this._installer) : super(RuntimeState.initial()) {
    on<RuntimeStarted>(_onRefresh);
    on<RuntimeRefreshed>(_onRefresh);
    on<RuntimeInstallRequested>(_onInstall);
    on<RuntimeCancelRequested>(_onCancel);
    on<RuntimeSelectRequested>(_onSelect);
    on<RuntimeRemoveRequested>(_onRemove);
    on<RuntimeProgressReceived>(_onProgress);
    on<RuntimeStatusReceived>(_onStatusReceived);
    on<RuntimeInstallCompleted>(_onInstallCompleted);
    on<RuntimeActionCompleted>(_onActionCompleted);
  }

  final RuntimeStatusReader _reader;
  final RuntimeInstallService _installer;

  RuntimeCancelToken? _cancelToken;

  Future<void> _onRefresh(
    RuntimeEvent event,
    Emitter<RuntimeState> emit,
  ) async {
    if (state.busy || state.installing) {
      return;
    }
    emit(state.rebuild((b) => b..loading = true));
    try {
      final status = await _reader.read();
      if (isClosed) {
        return;
      }
      add(RuntimeStatusReceived(status: status));
    } on Object catch (error) {
      if (isClosed) {
        return;
      }
      add(RuntimeStatusReceived(error: '$error'));
    }
  }

  void _onStatusReceived(
    RuntimeStatusReceived event,
    Emitter<RuntimeState> emit,
  ) {
    final status = event.status;
    if (status == null) {
      emit(
        state.rebuild(
          (b) => b
            ..loading = false
            ..errorCode = RuntimeErrorCode.statusReadFailed
            ..errorDetail = event.error,
        ),
      );
      return;
    }
    final hardware = status.detection.hardware;
    final gate = status.gate;
    final manifest = status.selectedManifest;
    emit(
      state.rebuild((b) {
        b
          ..loading = false
          ..errorCode = null
          ..errorDetail = null
          ..operatingSystem = _operatingSystem(status.detection)
          ..gpuSummary = _gpuSummary(status.detection)
          ..hasGpu = hardware.gpus.isNotEmpty
          ..platform = hardware.platform
          ..supports.replace(status.detection.supports)
          ..recommendedBackend = status.recommendedBackend
          ..recommendationReason = status.detection.recommendedReason
          ..offeredBackends.replace(status.offeredBackends)
          ..installed.replace(status.installs)
          ..selectedTag = status.selected?.tag
          ..selectedBackend = status.selected?.backend
          ..selectedVersion = manifest?.llamaVersion
          ..gateVerdict = gate.verdict
          ..gateReason = gate.reason;
      }),
    );
  }

  Future<void> _onInstall(
    RuntimeInstallRequested event,
    Emitter<RuntimeState> emit,
  ) async {
    if (state.busy || state.installing) {
      return;
    }
    final asset = _installer.release.forBackend(
      event.backend,
      state.platform ?? RuntimePlatform.linuxX64,
    );
    if (state.platform == null || asset == null) {
      emit(
        state.rebuild(
          (b) => b
            ..errorCode = RuntimeErrorCode.unavailableOnHost
            ..errorDetail = event.backend.displayName,
        ),
      );
      return;
    }

    final cancel = RuntimeCancelToken();
    _cancelToken = cancel;
    emit(
      state.rebuild(
        (b) => b
          ..busy = true
          ..installingBackend = event.backend
          ..progressReceived = 0
          ..progressTotal =
              asset.sizeBytes + (asset.cudartAsset?.sizeBytes ?? 0)
          ..bytesPerSecond = 0
          ..errorCode = null
          ..errorDetail = null
          ..noticeCode = null
          ..noticeDetail = null,
      ),
    );

    try {
      await _installer.install(
        asset: asset,
        force: event.force,
        cancel: cancel,
        onProgress: (progress) {
          if (!isClosed) {
            add(RuntimeProgressReceived(progress));
          }
        },
      );
      if (!isClosed) {
        add(const RuntimeInstallCompleted());
      }
    } on RuntimeException catch (error) {
      if (!isClosed) {
        add(
          RuntimeInstallCompleted(
            error: error.message,
            cancelled: error.code == RuntimeFailureCode.cancelled,
          ),
        );
      }
    } on StateError catch (error) {
      if (!isClosed) {
        add(RuntimeInstallCompleted(error: error.message));
      }
    } on Object catch (error) {
      if (!isClosed) {
        add(RuntimeInstallCompleted(error: '$error'));
      }
    } finally {
      _cancelToken = null;
    }
  }

  void _onCancel(RuntimeCancelRequested event, Emitter<RuntimeState> emit) {
    _cancelToken?.cancel();
    emit(
      state.rebuild(
        (b) => b
          ..noticeCode = RuntimeNoticeCode.cancelling
          ..noticeDetail = null,
      ),
    );
  }

  void _onProgress(RuntimeProgressReceived event, Emitter<RuntimeState> emit) {
    if (!state.installing) {
      return;
    }
    emit(
      state.rebuild(
        (b) => b
          ..progressReceived = event.progress.received
          ..progressTotal = event.progress.total
          ..bytesPerSecond = event.progress.bytesPerSecond,
      ),
    );
  }

  void _onInstallCompleted(
    RuntimeInstallCompleted event,
    Emitter<RuntimeState> emit,
  ) {
    final backend = state.installingBackend;
    emit(
      state.rebuild(
        (b) => b
          ..busy = false
          ..installingBackend = null
          ..bytesPerSecond = 0
          ..errorCode = event.cancelled || event.error == null
              ? null
              : RuntimeErrorCode.installFailed
          ..errorDetail = event.cancelled ? null : event.error
          ..noticeCode = event.cancelled
              ? RuntimeNoticeCode.installCancelled
              : event.error == null && backend != null
              ? RuntimeNoticeCode.installed
              : null
          ..noticeDetail = backend?.displayName,
      ),
    );
    if (event.error == null && !event.cancelled) {
      _refreshAfterAction();
    }
  }

  Future<void> _onSelect(
    RuntimeSelectRequested event,
    Emitter<RuntimeState> emit,
  ) async {
    if (state.busy || state.installing) {
      return;
    }
    emit(state.rebuild((b) => b..busy = true));
    try {
      await _reader.store.select(event.tag, event.backend);
      if (!isClosed) {
        add(
          RuntimeActionCompleted(
            noticeCode: RuntimeNoticeCode.selected,
            noticeDetail: '${event.tag}/${event.backend.id}',
          ),
        );
      }
    } on Object catch (error) {
      if (!isClosed) {
        add(RuntimeActionCompleted(error: '$error'));
      }
    }
  }

  Future<void> _onRemove(
    RuntimeRemoveRequested event,
    Emitter<RuntimeState> emit,
  ) async {
    if (state.busy || state.installing) {
      return;
    }
    emit(state.rebuild((b) => b..busy = true));
    try {
      await _reader.store.remove(event.tag, event.backend);
      if (!isClosed) {
        add(
          RuntimeActionCompleted(
            noticeCode: RuntimeNoticeCode.removed,
            noticeDetail: '${event.tag}/${event.backend.id}',
          ),
        );
      }
    } on Object catch (error) {
      if (!isClosed) {
        add(RuntimeActionCompleted(error: '$error'));
      }
    }
  }

  void _onActionCompleted(
    RuntimeActionCompleted event,
    Emitter<RuntimeState> emit,
  ) {
    emit(
      state.rebuild(
        (b) => b
          ..busy = false
          ..errorCode = event.error == null
              ? null
              : RuntimeErrorCode.actionFailed
          ..errorDetail = event.error
          ..noticeCode = event.noticeCode
          ..noticeDetail = event.noticeDetail,
      ),
    );
    if (event.error == null) {
      _refreshAfterAction();
    }
  }

  void _refreshAfterAction() {
    if (isClosed) {
      return;
    }
    add(const RuntimeRefreshed());
  }

  /// The operating system and the architecture of the host.
  static String _operatingSystem(RuntimeDetection detection) {
    final hardware = detection.hardware;
    return '${hardware.operatingSystem} ${hardware.arch}';
  }

  /// The detected GPUs and their drivers.
  static String _gpuSummary(RuntimeDetection detection) {
    final hardware = detection.hardware;
    return hardware.gpus
        .map((gpu) => '${gpu.name} (${gpu.vendor} ${gpu.driverVersion})')
        .join(' · ');
  }

  /// Convenience for tests and the card: the pinned release's asset for
  /// [backend] on the detected host.
  RuntimeAsset? assetFor(RuntimeBackend backend) {
    final platform = state.platform;
    if (platform == null) {
      return null;
    }
    return _installer.release.forBackend(backend, platform);
  }
}
