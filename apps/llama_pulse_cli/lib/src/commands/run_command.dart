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
/// Without `--stub` the worker runs the native session named by `--lib` or
/// resolved by the worker. In stub mode the model path is echoed into the
/// request but never read.
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
      'Run one prompt through the embedded engine. --stub echoes the model '
      'path without reading it; --lib selects the native llama.cpp library.';

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

    final promptArgumentError = _promptArgumentError(args);
    if (promptArgumentError != null) {
      services.err.writeln('error: $promptArgumentError');
      return ExitCodes.usage;
    }

    final parsed = parseInferenceOptions(args);
    if (parsed.errors.isNotEmpty) {
      for (final message in parsed.errors) {
        services.err.writeln('error: $message');
      }
      return ExitCodes.usage;
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

    // The stub echoes the path without opening it, so only the native session
    // needs a readable `.gguf` file. Checking here keeps a typo from surfacing
    // later as libraryNotFound.
    final stub = args.flag('stub');
    if (!stub && await services.scanner.inspect(modelPath) == null) {
      services.err.writeln('error: not found: $modelPath');
      if (mode == RunOutputMode.stream || mode == RunOutputMode.json) {
        services.out.writeln(
          jsonEncode(encodeFailed(1, '', missingModelFailure(modelPath))),
        );
      }
      return ExitCodes.notFound;
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

    // Reading the prompt is last, so `--file -` never blocks on stdin for an
    // invocation that is already invalid.
    final prompt = await _resolvePrompt(args);
    if (prompt == null) {
      return ExitCodes.usage;
    }

    final engine = services.createEngine(
      useStubSession: stub,
      libraryPath: parsed.libraryPath,
    );
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

  String? _promptArgumentError(ArgResults args) {
    final prompt = args.option('prompt');
    final file = args.option('file');
    if (prompt != null && file != null) {
      return '--prompt and --file cannot be combined';
    }
    if (prompt == null && file == null) {
      return 'pass either --prompt or --file';
    }
    return null;
  }

  Future<String?> _resolvePrompt(ArgResults args) async {
    final prompt = args.option('prompt');
    if (prompt != null) {
      return prompt;
    }
    final file = args.option('file');
    if (file == null) {
      // _promptArgumentError rejects this before any I/O happens.
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
      return utf8.decode(await File(file).readAsBytes());
    } on FormatException catch (error) {
      services.err.writeln(
        'error: cannot decode --file $file as UTF-8: ${error.message}',
      );
      return null;
    } on FileSystemException catch (error) {
      services.err.writeln('error: cannot read --file $file: ${error.message}');
      return null;
    }
  }

  int _reportFailure(InferenceFailure failure, RunOutputMode mode) {
    services.err.writeln('error: ${failure.code.name}: ${failure.message}');
    final details = failure.details;
    if (details != null && details.trim().isNotEmpty) {
      for (final line in details.split('\n')) {
        services.err.writeln('  $line');
      }
    }
    if (mode == RunOutputMode.stream || mode == RunOutputMode.json) {
      services.out.writeln(jsonEncode(encodeFailed(1, '', failure)));
    }
    return ExitCodes.failure;
  }

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
