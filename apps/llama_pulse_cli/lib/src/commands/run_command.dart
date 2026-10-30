import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../inference/output_schema.dart';
import '../inference/run_options.dart';
import '../inference/run_session.dart';

/// Runs one prompt through the inference engine.
///
/// The native engine does not exist yet, so this command requires `--stub`.
/// In stub mode the model path is echoed into the request but never read; no
/// file-existence check happens in this batch.
final class RunCommand extends LlamaPulseCommand {
  /// Creates the command.
  RunCommand(super.services) {
    addInferenceOptions(argParser);
    argParser
      ..addOption('prompt', help: 'Prompt text to send to the model.')
      ..addOption(
        'file',
        help: 'Read the prompt from a file; "-" reads standard input.',
      )
      ..addFlag(
        'stream',
        negatable: false,
        help: 'Emit one NDJSON object per line.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Emit exactly one final JSON object.',
      )
      ..addFlag(
        'stub',
        negatable: false,
        help: 'Use the deterministic stub engine.',
      );
  }

  @override
  String get name => 'run';

  @override
  String get description =>
      'Run one prompt. Requires --stub until the native engine lands; the '
      'model path is echoed but not read in this batch.';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final args = parsedArgs;
    if (args.flag('json') && args.flag('stream')) {
      services.err.writeln('error: --json and --stream cannot be combined');
      return ExitCodes.usage;
    }
    final mode = _mode(args);

    final prompt = await _resolvePrompt(args);
    if (prompt == null) {
      return ExitCodes.usage;
    }

    final parsed = parseInferenceOptions(args);
    if (parsed.errors.isNotEmpty) {
      for (final message in parsed.errors) {
        services.err.writeln('error: $message');
      }
      return ExitCodes.usage;
    }

    if (!args.flag('stub')) {
      return _engineUnavailable(mode);
    }

    final stored = await services.paramsRepository.load();
    final modelPath = resolveModelPath(args.option('model'), stored.modelPath);
    if (modelPath == null) {
      services.err.writeln(
        'error: model path is required: pass --model or set '
        'params.modelPath',
      );
      return ExitCodes.usage;
    }

    final params = parsed.overrides
        .applyTo(stored)
        .copyWith(modelPath: modelPath);
    final violations = const ModelParamsValidator().validate(params);
    if (violations.isNotEmpty) {
      for (final violation in violations) {
        services.err.writeln('error: $violation');
      }
      return ExitCodes.usage;
    }

    final engine = services.createEngine(useStubSession: true);
    try {
      try {
        await engine.load(params);
      } on InferenceFailureException catch (error) {
        return _reportFailure(error.failure, mode);
      }
      final result = await runSession(
        engine: engine,
        request: GenerationRequest.create(
          requestId: 1,
          prompt: prompt,
          params: params,
        ),
        out: services.out,
        err: services.err,
        mode: mode,
        interrupts: services.interrupts,
      );
      return result.exitCode;
    } finally {
      try {
        await engine.dispose();
      } catch (_) {
        // Disposal is best-effort; the command result is already decided.
      }
    }
  }

  Future<String?> _resolvePrompt(ArgResults args) async {
    final prompt = args.option('prompt');
    final file = args.option('file');
    if (prompt != null && file != null) {
      services.err.writeln('error: --prompt and --file cannot be combined');
      return null;
    }
    if (prompt != null) {
      return prompt;
    }
    if (file == null) {
      services.err.writeln('error: pass either --prompt or --file');
      return null;
    }
    if (file == '-') {
      final source = services.stdin;
      if (source == null) {
        services.err.writeln('error: --file - requires standard input');
        return null;
      }
      try {
        return await utf8.decoder.bind(source).join();
      } on FormatException catch (error) {
        services.err.writeln(
          'error: cannot decode standard input as UTF-8: ${error.message}',
        );
        return null;
      }
    }
    try {
      return await File(file).readAsString();
    } on FileSystemException catch (error) {
      services.err.writeln('error: cannot read --file $file: ${error.message}');
      return null;
    }
  }

  int _engineUnavailable(RunOutputMode mode) {
    const message = 'the native engine is not implemented yet; pass --stub';
    services.err.writeln('error: engineUnavailable: $message');
    if (mode == RunOutputMode.stream || mode == RunOutputMode.json) {
      services.out.writeln(jsonEncode(encodeFailed(0, '', _failure(message))));
    }
    return ExitCodes.failure;
  }

  int _reportFailure(InferenceFailure failure, RunOutputMode mode) {
    services.err.writeln('error: ${failure.code.name}: ${failure.message}');
    if (mode == RunOutputMode.stream || mode == RunOutputMode.json) {
      services.out.writeln(jsonEncode(encodeFailed(1, '', failure)));
    }
    return ExitCodes.failure;
  }

  InferenceFailure _failure(String message) => InferenceFailure(
    (b) => b
      ..code = InferenceFailureCode.engineUnavailable
      ..message = message,
  );

  RunOutputMode _mode(ArgResults args) {
    if (args.flag('json')) {
      return RunOutputMode.json;
    }
    if (args.flag('stream')) {
      return RunOutputMode.stream;
    }
    return RunOutputMode.human;
  }
}
