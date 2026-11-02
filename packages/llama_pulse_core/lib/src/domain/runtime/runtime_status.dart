import '../entities/runtime_index.dart';
import '../entities/runtime_install_ref.dart';
import '../entities/runtime_manifest.dart';
import 'runtime_backend.dart';
import 'runtime_probe.dart';
import 'runtime_release.dart';

/// What the native version gate would decide for the selected runtime.
enum RuntimeGateVerdict {
  /// No runtime is selected, so there is nothing to check.
  notInstalled,

  /// The install records a local `LLAMA_BUILD_IS_DEV=OFF` build reporting
  /// `0.8.0`; the exact gate accepts it.
  exact,

  /// The install is an official prebuilt archive reporting `0.8.0-dev`, and
  /// its manifest matches the pin.
  attested,

  /// The install records no version, so the gate cannot predict a decision.
  unknown,

  /// The install does not match the pin; the gate rejects the library.
  rejected,
}

/// The gate verdict for one runtime, with the evidence behind it.
final class RuntimeGate {
  /// Creates a verdict.
  const RuntimeGate({required this.verdict, required this.reason});

  /// The verdict for a host with no selected runtime.
  static const RuntimeGate notInstalled = RuntimeGate(
    verdict: RuntimeGateVerdict.notInstalled,
    reason: 'no runtime is selected',
  );

  /// The verdict.
  final RuntimeGateVerdict verdict;

  /// Human-readable evidence.
  final String reason;

  /// Whether the native gate accepts the selected runtime.
  bool get accepted =>
      verdict == RuntimeGateVerdict.exact ||
      verdict == RuntimeGateVerdict.attested;

  /// The wire name used by `runtime status --json`.
  String get wireName => switch (verdict) {
    RuntimeGateVerdict.notInstalled => 'notInstalled',
    RuntimeGateVerdict.exact => 'exact',
    RuntimeGateVerdict.attested => 'attested',
    RuntimeGateVerdict.unknown => 'unknown',
    RuntimeGateVerdict.rejected => 'rejected',
  };
}

/// One host's runtime state: hardware, installed runtimes and the gate verdict.
final class RuntimeStatus {
  /// Creates a status snapshot.
  RuntimeStatus({
    required this.detection,
    required this.release,
    required this.index,
    required this.gate,
    this.selectedManifest,
  });

  /// What the probe found on the host.
  final RuntimeDetection detection;

  /// The release this build installs.
  final RuntimeRelease release;

  /// The parsed `runtime/index.yaml`.
  final RuntimeIndex index;

  /// The gate verdict for the selected runtime.
  final RuntimeGate gate;

  /// The manifest of the selected runtime, when it is installed and readable.
  final RuntimeManifest? selectedManifest;

  /// The backend a fresh install should default to, or null when unsupported.
  RuntimeBackend? get recommendedBackend => detection.recommendedBackend;

  /// Every install, selected first and then newest first.
  List<RuntimeInstallRef> get installs => index.resolutionOrder;

  /// The selected install, or null when nothing is selected.
  RuntimeInstallRef? get selected => index.selected;

  /// The backends the pinned release can offer on this host.
  List<RuntimeBackend> get offeredBackends {
    final platform = detection.hardware.platform;
    if (platform == null) {
      return const <RuntimeBackend>[];
    }
    return release.backendsFor(platform);
  }
}
