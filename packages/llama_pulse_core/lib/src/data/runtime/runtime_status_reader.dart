import '../../domain/entities/runtime_manifest.dart';
import '../../domain/gateways/runtime_store.dart';
import '../../domain/runtime/runtime_probe.dart';
import '../../domain/runtime/runtime_release.dart';
import '../../domain/runtime/runtime_status.dart';
import 'runtime_attestation.dart';

/// Reads the host and the installed runtimes into one [RuntimeStatus].
final class RuntimeStatusReader {
  /// Creates a reader over the injected store and probe.
  const RuntimeStatusReader({
    required this.store,
    required this.probe,
    this.release = RuntimeRelease.v080,
  });

  /// Reads the installed runtime index.
  final RuntimeStore store;

  /// Detects the host hardware.
  final RuntimeProbe probe;

  /// The pinned release the installs come from.
  final RuntimeRelease release;

  /// Probes the host, reads the index and evaluates the gate for the
  /// selected runtime.
  Future<RuntimeStatus> read() async {
    final detection = await probe.probe();
    final index = await store.index();
    final selected = index.selected;
    RuntimeManifest? manifest;
    var gate = RuntimeGate.notInstalled;
    if (selected != null) {
      manifest = await store.manifest(selected.tag, selected.backend);
      gate = _gateFor(manifest);
    }
    return RuntimeStatus(
      detection: detection,
      release: release,
      index: index,
      gate: gate,
      selectedManifest: manifest,
    );
  }

  RuntimeGate _gateFor(RuntimeManifest? manifest) {
    if (manifest == null) {
      return const RuntimeGate(
        verdict: RuntimeGateVerdict.rejected,
        reason: 'the selected runtime has no readable runtime.yaml',
      );
    }
    final version = manifest.llamaVersion?.trim() ?? '';
    if (version.isEmpty) {
      return const RuntimeGate(
        verdict: RuntimeGateVerdict.unknown,
        reason: 'the install did not record a llama.cpp version',
      );
    }
    if (version == '0.8.0') {
      return const RuntimeGate(
        verdict: RuntimeGateVerdict.exact,
        reason: 'the install reports 0.8.0',
      );
    }
    if (version == '0.8.0-dev') {
      final attestation = RuntimeAttestation.verify(manifest, release: release);
      return RuntimeGate(
        verdict: attestation.isAttested
            ? RuntimeGateVerdict.attested
            : RuntimeGateVerdict.rejected,
        reason: attestation.reason,
      );
    }
    return RuntimeGate(
      verdict: RuntimeGateVerdict.rejected,
      reason: 'the install reports $version, not ${release.tag}',
    );
  }
}
