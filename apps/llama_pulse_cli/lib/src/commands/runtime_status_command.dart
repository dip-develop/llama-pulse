import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../runtime/runtime_output.dart';

/// Reports the host hardware, the installed runtimes and the gate verdict.
final class RuntimeStatusCommand extends LlamaPulseCommand {
  /// Creates the command.
  RuntimeStatusCommand(super.services) {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print the runtime status as a single-line JSON object.',
    );
  }

  @override
  String get name => 'status';

  @override
  String get description =>
      'Report the detected hardware, installed runtimes and gate verdict.';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final status = await services.createRuntimeStatusReader().read();
    if (parsedArgs.flag('json')) {
      writeJsonLine(services.out, encodeRuntimeStatus(status));
    } else {
      _writeHuman(status);
    }
    return status.detection.hardware.platform == null
        ? ExitCodes.failure
        : ExitCodes.ok;
  }

  void _writeHuman(RuntimeStatus status) {
    final out = services.out;
    final hardware = status.detection.hardware;
    final platform = hardware.platform;
    out.writeln(
      'host: ${hardware.operatingSystem}/${hardware.arch} '
      '(${platform?.id ?? 'unsupported'})',
    );
    for (final gpu in hardware.gpus) {
      out.writeln(
        'gpu: ${gpu.name} (${gpu.vendor}, driver ${gpu.driverVersion})',
      );
    }
    if (hardware.gpus.isEmpty) {
      out.writeln('gpu: none detected');
    }
    out.writeln(
      'detected: cuda=${hardware.hasCuda} rocm=${hardware.hasRocm} '
      'vulkan=${hardware.hasVulkan}',
    );
    final recommendation = status.detection.recommendation;
    if (recommendation == null) {
      out.writeln('recommendation: none');
    } else {
      out.writeln(
        'recommendation: ${recommendation.backend.id} '
        '(${recommendation.reason})',
      );
    }
    out.writeln('release: ${status.release.tag} ${status.release.build}');
    if (status.offeredBackends.isEmpty) {
      out.writeln('backends: none for this host');
    } else {
      out.writeln(
        'backends: ${status.offeredBackends.map((b) => b.id).join(', ')}',
      );
    }
    final selected = status.selected;
    out.writeln('selected: ${selected?.id ?? 'none'}');
    out.writeln('installed: ${status.installs.length}');
    for (final install in status.installs) {
      out.writeln(
        '  ${install.id} ${install.platform.id} '
        '${formatRuntimeSize(install.sizeBytes)}',
      );
    }
    out.writeln(
      'gate: ${status.gate.wireName} '
      '(${status.gate.reason})',
    );
  }
}
