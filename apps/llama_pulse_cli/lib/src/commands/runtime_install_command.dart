import 'dart:async';
import 'dart:convert';

import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../runtime/runtime_commands_support.dart';
import '../runtime/runtime_output.dart';

/// Downloads, verifies and installs one pinned runtime backend.
final class RuntimeInstallCommand extends LlamaPulseCommand {
  /// Creates the command.
  RuntimeInstallCommand(super.services) {
    argParser
      ..addOption(
        'backend',
        help: 'Backend to install, for example cpu, cuda13, vulkan or rocm.',
        valueHelp: 'id',
      )
      ..addOption(
        'tag',
        defaultsTo: RuntimeRelease.v080.tag,
        help: 'Pinned llama.cpp release to install.',
        valueHelp: 'tag',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Replace an already installed runtime.',
      )
      ..addFlag(
        'yes',
        abbr: 'y',
        negatable: false,
        help: 'Accept the CUDA runtime download without prompting.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Emit NDJSON progress and one install object on stdout.',
      );
  }

  @override
  String get name => 'install';

  @override
  String get description =>
      'Download, verify and install a pinned llama.cpp runtime.';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final json = parsedArgs.flag('json');
    final release = services.runtimeRelease;
    final tag = parsedArgs.option('tag')!.trim();
    if (tag != release.tag) {
      return _usage(
        json,
        'unknown release "$tag"; this build installs ${release.tag}',
      );
    }
    final backendId = parsedArgs.option('backend')?.trim() ?? '';
    if (backendId.isEmpty) {
      return _usage(json, '--backend is required');
    }
    final backend = parseRuntimeBackend(backendId);
    if (backend == null) {
      return _usage(
        json,
        'unknown backend "$backendId"; choose one of '
        '${RuntimeBackend.values.map((b) => b.id).join(', ')}',
      );
    }

    final status = await services.createRuntimeStatusReader().read();
    final platform = status.detection.hardware.platform;
    if (platform == null) {
      return _usage(
        json,
        'the pinned release has no build for '
        '${status.detection.hardware.operatingSystem}/'
        '${status.detection.hardware.arch}',
      );
    }
    final asset = runtimeAssetFor(release, backend, platform);
    if (asset == null) {
      return _usage(
        json,
        '${release.tag} has no ${backend.id} archive for ${platform.id}',
      );
    }

    final refusal = await _confirmCudart(asset);
    if (refusal != null) {
      return _usage(json, refusal);
    }

    return _install(asset, json: json);
  }

  Future<int> _install(RuntimeAsset asset, {required bool json}) async {
    final installer = services.createRuntimeInstaller();
    final cancel = RuntimeCancelToken();
    var interrupted = false;
    final interrupts = services.interrupts;
    final subscription = interrupts?.listen((_) {
      interrupted = true;
      cancel.cancel();
    });

    var lastDecile = -1;
    void onProgress(RuntimeProgress progress) {
      if (json) {
        writeJsonLine(
          services.out,
          encodeRuntimeProgress(asset.backend, progress),
        );
        return;
      }
      final decile = (progress.fraction * 10).floor();
      if (decile == lastDecile) {
        return;
      }
      lastDecile = decile;
      final throughput = progress.bytesPerSecond <= 0
          ? ''
          : ' (${formatRuntimeSize(progress.bytesPerSecond.round())}/s)';
      services.err.writeln(
        'downloading ${asset.assetName}: '
        '${(progress.fraction * 100).floor()}% '
        '${formatRuntimeSize(progress.received)} of '
        '${formatRuntimeSize(progress.total)}$throughput',
      );
    }

    final cudart = asset.cudartAsset;
    services.err
      ..writeln(
        'installing ${asset.backend.id} for ${asset.platform.id}: '
        '${formatRuntimeSize(asset.sizeBytes)}',
      )
      ..writeln('requires: ${asset.requirements}');
    if (cudart != null) {
      services.err.writeln(
        'including the CUDA runtime: ${formatRuntimeSize(cudart.sizeBytes)}',
      );
    }

    try {
      final result = await installer.install(
        asset: asset,
        onProgress: onProgress,
        cancel: cancel,
        force: parsedArgs.flag('force'),
      );
      if (json) {
        writeJsonLine(services.out, encodeRuntimeInstall(result));
      } else {
        services.out.writeln(
          'installed ${result.tag}/${result.backend.id} at '
          '${result.payloadDir.path}',
        );
      }
      return ExitCodes.ok;
    } on RuntimeException catch (error) {
      if (interrupted || error.code == RuntimeFailureCode.cancelled) {
        services.err.writeln('interrupted; the install was cancelled');
        return ExitCodes.interrupted;
      }
      return _failed(json, error);
    } on StateError catch (error) {
      return _usage(json, error.message);
    } finally {
      await subscription?.cancel();
    }
  }

  int _failed(bool json, RuntimeException error) {
    final code = exitCodeForRuntimeFailure(error.code);
    services.err.writeln('error: ${error.message}');
    if (json) {
      writeJsonLine(
        services.out,
        encodeRuntimeFailed(
          command: 'install',
          code: error.code.name,
          message: error.message,
          expected: error.expected,
          actual: error.actual,
        ),
      );
    }
    return code;
  }

  int _usage(bool json, String message) {
    services.err.writeln('error: $message');
    if (json) {
      writeJsonLine(
        services.out,
        encodeRuntimeFailed(
          command: 'install',
          code: 'usage',
          message: message,
        ),
      );
    }
    return ExitCodes.usage;
  }

  /// Asks before a CUDA runtime archive is downloaded with the build.
  ///
  /// `--yes` is the non-interactive path. Without a stdin the command refuses
  /// instead of guessing, because the archive adds hundreds of megabytes and a
  /// driver floor the host may not meet.
  Future<String?> _confirmCudart(RuntimeAsset asset) async {
    final cudart = asset.cudartAsset;
    if (cudart == null || parsedArgs.flag('yes')) {
      return null;
    }
    final stdin = services.stdin;
    if (stdin == null) {
      return '${asset.backend.id} also installs the CUDA runtime '
          '(${formatRuntimeSize(cudart.sizeBytes)}); pass --yes to accept';
    }
    services.err
      ..writeln(
        '${asset.backend.id} also installs the CUDA runtime '
        '(${formatRuntimeSize(cudart.sizeBytes)}).',
      )
      ..writeln('requires: ${asset.requirements}')
      ..write('continue? [y/N] ');
    final line = await stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    final answer = line.trim().toLowerCase();
    return answer == 'y' || answer == 'yes' ? null : 'installation declined';
  }
}
