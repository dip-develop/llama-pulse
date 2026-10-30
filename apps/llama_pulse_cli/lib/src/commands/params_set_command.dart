import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';

/// Applies flags to the stored model parameters and saves them.
final class ParamsSetCommand extends LlamaPulseCommand {
  /// Creates the command.
  ParamsSetCommand(super.services) {
    argParser
      ..addOption('model-path', help: 'Path to the model file.')
      ..addOption('context-size', help: 'Context window, in tokens.')
      ..addOption('gpu-layers', help: 'Layers offloaded to the GPU.')
      ..addOption('threads', help: 'Worker threads used for evaluation.')
      ..addOption('temperature', help: 'Sampling temperature.')
      ..addOption('top-p', help: 'Nucleus sampling probability mass.')
      ..addOption('top-k', help: 'Top-k sampling cutoff.')
      ..addOption('max-tokens', help: 'Upper bound on generated tokens.')
      ..addFlag(
        'reset',
        negatable: false,
        help: 'Restore the default parameters instead of updating them.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print the saved parameters as a single-line JSON object.',
      );
  }

  @override
  String get name => 'set';

  @override
  String get description =>
      'Validate and store model parameters. Config file: '
      '${services.paths.paramsYamlFile}';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final args = parsedArgs;
    final reset = args.flag('reset');
    if (reset && _hasParameterOptions) {
      services.err.writeln(
        'error: --reset cannot be combined with other parameter options',
      );
      return ExitCodes.usage;
    }

    final invalid = <String>[];
    int? readInt(String name) {
      final raw = args.option(name);
      if (raw == null) {
        return null;
      }
      final value = int.tryParse(raw);
      if (value == null) {
        invalid.add("invalid value for --$name: '$raw'");
      }
      return value;
    }

    double? readDouble(String name) {
      final raw = args.option(name);
      if (raw == null) {
        return null;
      }
      final value = double.tryParse(raw);
      if (value == null) {
        invalid.add("invalid value for --$name: '$raw'");
      }
      return value;
    }

    final modelPath = args.option('model-path');
    final contextSize = readInt('context-size');
    final gpuLayers = readInt('gpu-layers');
    final threads = readInt('threads');
    final temperature = readDouble('temperature');
    final topP = readDouble('top-p');
    final topK = readInt('top-k');
    final maxTokens = readInt('max-tokens');

    if (invalid.isNotEmpty) {
      for (final message in invalid) {
        services.err.writeln('error: $message');
      }
      return ExitCodes.usage;
    }

    var params = reset
        ? ModelParams.defaults()
        : await services.paramsRepository.load();
    if (!reset) {
      params = params.copyWith(
        modelPath: modelPath,
        contextSize: contextSize,
        gpuLayers: gpuLayers,
        threads: threads,
        temperature: temperature,
        topP: topP,
        topK: topK,
        maxTokens: maxTokens,
      );
    }

    try {
      await services.paramsRepository.save(params);
    } on InvalidModelParamsException catch (error) {
      for (final violation in error.violations) {
        services.err.writeln('error: $violation');
      }
      return ExitCodes.usage;
    }

    writeParamsDocument(
      services.out,
      services.paramsRepository.toDocument(params),
      json: args.flag('json'),
    );
    return ExitCodes.ok;
  }

  bool get _hasParameterOptions {
    for (final name in _parameterOptions) {
      if (parsedArgs.option(name) != null) {
        return true;
      }
    }
    return false;
  }

  static const List<String> _parameterOptions = [
    'model-path',
    'context-size',
    'gpu-layers',
    'threads',
    'temperature',
    'top-p',
    'top-k',
    'max-tokens',
  ];
}
