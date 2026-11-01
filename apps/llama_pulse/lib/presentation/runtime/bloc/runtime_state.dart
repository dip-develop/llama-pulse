import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

part 'runtime_state.g.dart';

/// Immutable snapshot rendered by the Runtime tab and the dashboard card.
///
/// It keeps primitives and `built_value` entities only: the probe result is
/// flattened into a summary and the per-backend verdicts, so the state stays
/// comparable and serializable.
abstract class RuntimeState
    implements Built<RuntimeState, RuntimeStateBuilder> {
  /// Whether the first status read is in flight.
  bool get loading;

  /// Whether an install, selection or removal is in flight.
  bool get busy;

  /// One-line description of the detected host, or null before the probe.
  String? get hardwareSummary;

  /// The platform the pinned release offers, or null on an unsupported host.
  RuntimePlatform? get platform;

  /// The probe's verdict for every backend the release offers on this host.
  BuiltList<BackendSupport> get supports;

  /// The backend a fresh install should default to.
  RuntimeBackend? get recommendedBackend;

  /// Why [recommendedBackend] won.
  String? get recommendationReason;

  /// Every backend the pinned release can install on this host.
  BuiltList<RuntimeBackend> get offeredBackends;

  /// Every installed runtime, selected first and then newest first.
  BuiltList<RuntimeInstallRef> get installed;

  /// Tag of the selected runtime, or null when none is selected.
  String? get selectedTag;

  /// Backend of the selected runtime, or null when none is selected.
  RuntimeBackend? get selectedBackend;

  /// The version the selected install reported, when it is known.
  String? get selectedVersion;

  /// The native gate verdict for the selected runtime.
  RuntimeGateVerdict? get gateVerdict;

  /// Why the gate reached [gateVerdict].
  String? get gateReason;

  /// The backend currently downloading, when an install runs.
  RuntimeBackend? get installingBackend;

  /// Bytes received by the running install.
  int get progressReceived;

  /// Total bytes the running install expects.
  int get progressTotal;

  /// Throughput of the running install in bytes per second.
  double get bytesPerSecond;

  /// Why the last action failed, or null when it succeeded.
  String? get errorMessage;

  /// Summary of the last successful action, or null.
  String? get noticeMessage;

  /// Whether a download is running.
  bool get installing => installingBackend != null;

  /// `tag/backend` of the selected runtime, or null.
  String? get selectedId {
    final backend = selectedBackend;
    final tag = selectedTag;
    if (backend == null || tag == null) {
      return null;
    }
    return '$tag/${backend.id}';
  }

  /// Fraction of the running download, clamped to `0..1`.
  double get progressFraction =>
      progressTotal <= 0 ? 0 : (progressReceived / progressTotal).clamp(0, 1);

  /// The probe verdict for [backend], or null when it was not probed.
  BackendSupport? supportFor(RuntimeBackend backend) {
    for (final support in supports) {
      if (support.backend == backend) {
        return support;
      }
    }
    return null;
  }

  /// Whether [backend] can run on this host.
  bool isSupported(RuntimeBackend backend) =>
      supportFor(backend)?.supported ?? false;

  /// Whether the native gate accepts the selected runtime.
  bool get gateAccepted =>
      gateVerdict == RuntimeGateVerdict.exact ||
      gateVerdict == RuntimeGateVerdict.attested;

  factory RuntimeState([void Function(RuntimeStateBuilder)? updates]) =
      _$RuntimeState;

  /// The state shown before the first probe completes.
  factory RuntimeState.initial() => RuntimeState(
    (b) => b
      ..loading = true
      ..busy = false
      ..supports = ListBuilder<BackendSupport>()
      ..offeredBackends = ListBuilder<RuntimeBackend>()
      ..installed = ListBuilder<RuntimeInstallRef>()
      ..progressReceived = 0
      ..progressTotal = 0
      ..bytesPerSecond = 0,
  );

  RuntimeState._();

  static Serializer<RuntimeState> get serializer => _$runtimeStateSerializer;
}
