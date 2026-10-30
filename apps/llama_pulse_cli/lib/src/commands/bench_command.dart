import 'dart:convert';

import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../inference/output_schema.dart';
import '../inference/run_options.dart';
import '../inference/run_session.dart';

/// Prompt every benchmark run uses.
const String benchPrompt = 'The quick brown fox jumps over the lazy dog.';

/// Model path echoed into the stub request when none is configured.
///
/// The stub never opens the file, so this keeps `bench --stub` usable in a
/// fresh configuration directory without inventing a real path.
const String _stubOnlyModelPath = '<stub>';

/// Runs the same prompt several times and reports aggregate throughput.
///
/// The native session is unavailable, so this command requires `--stub`.
/// The fixed prompt is [benchPrompt].
final class BenchCommand extends LlamaPulseCommand {
  /// Creates the command.
  BenchCommand(super.services) {
    addInferenceOptions(argParser, maxTokensDefault: '32');
    argParser
      ..addFlag(
        'stub',
        negatable: false,
        help: 'Use the deterministic stub engine.',
      )
      ..addOption(
        'runs',
        defaultsTo: '3',
        help: 'Number of sequential runs, 1..50.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print the aggregate result as a single JSON object.',
      );
  }

  @override
  String get name => 'bench';

  @override
  String get description =>
      'Benchmark repeated runs of "$benchPrompt". Requires --stub: the native '
      'session is unavailable, and stub mode without a configured model uses '
      'the $_stubOnlyModelPath placeholder.';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final args = parsedArgs;
    final rawRuns = args.option('runs') ?? '3';
    final runs = int.tryParse(rawRuns);
    if (runs == null || runs < 1 || runs > 50) {
      services.err.writeln(
        "error: --runs must be an integer in 1..50, got '$rawRuns'",
      );
      return ExitCodes.usage;
    }

    final parsed = parseInferenceOptions(args);
    if (parsed.errors.isNotEmpty) {
      for (final message in parsed.errors) {
        services.err.writeln('error: $message');
      }
      return ExitCodes.usage;
    }

    final json = args.flag('json');
    final stub = args.flag('stub');
    if (!stub) {
      return _engineUnavailable(json);
    }

    final stored = await services.paramsRepository.load();
    final configuredPath = resolveModelPath(
      args.option('model'),
      stored.modelPath,
    );
    // A benchmark without a configured model still exercises the stub; the
    // native engine branch above never reaches this point.
    final modelPath = configuredPath ?? _stubOnlyModelPath;

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
    var loaded = false;
    try {
      try {
        await engine.load(params);
        loaded = true;
      } on InferenceFailureException catch (error) {
        return _reportFailure(error.failure, 1, json);
      }

      final perRun = <Map<String, Object?>>[];
      var totalGenerated = 0;
      var totalEvalMs = 0;
      var promptTokenCount = 0;

      for (var index = 0; index < runs; index++) {
        final requestId = index + 1;
        final result = await runSession(
          engine: engine,
          request: GenerationRequest.create(
            requestId: requestId,
            prompt: benchPrompt,
            params: params,
          ),
          out: services.out,
          err: services.err,
          mode: RunOutputMode.quiet,
          interrupts: services.interrupts,
        );
        if (result.status == SessionStatus.cancelled) {
          if (json) {
            services.out.writeln(
              jsonEncode(encodeCancelled(requestId, result.text)),
            );
          } else {
            if (result.text.isNotEmpty) {
              services.out.writeln(result.text);
            }
            services.err.writeln('cancelled');
          }
          return ExitCodes.interrupted;
        }
        if (result.status == SessionStatus.failed) {
          return _reportFailure(
            result.failure ??
                InferenceFailure(
                  (b) => b
                    ..code = InferenceFailureCode.unknown
                    ..message = 'The benchmark run failed.',
                ),
            requestId,
            json,
            text: result.text,
          );
        }

        final metrics = result.metrics ?? _zeroMetrics;
        final tokensPerSecond = metrics.evalMs <= 0
            ? 0.0
            : metrics.generatedTokenCount * 1000 / metrics.evalMs;
        totalGenerated += metrics.generatedTokenCount;
        totalEvalMs += metrics.evalMs;
        if (index == 0) {
          promptTokenCount = metrics.promptTokenCount;
        }
        perRun.add({
          'requestId': requestId,
          'generatedTokenCount': metrics.generatedTokenCount,
          'evalMs': metrics.evalMs,
          'tokensPerSecond': roundToTwoDecimals(tokensPerSecond),
        });
        if (!json) {
          services.err.writeln(
            'run $requestId: ${metrics.generatedTokenCount} tokens in '
            '${metrics.evalMs} ms '
            '(${tokensPerSecond.toStringAsFixed(2)} tok/s)',
          );
        }
      }

      final aggregate = totalEvalMs <= 0
          ? 0.0
          : totalGenerated * 1000 / totalEvalMs;
      if (json) {
        services.out.writeln(
          jsonEncode({
            'schemaVersion': outputSchemaVersion,
            'type': 'bench',
            'runs': runs,
            'modelPath': modelPath,
            'promptChars': benchPrompt.length,
            'promptTokenCount': promptTokenCount,
            'generatedTokenCount': totalGenerated,
            'evalMs': totalEvalMs,
            'tokensPerSecond': roundToTwoDecimals(aggregate),
            'perRun': perRun,
          }),
        );
      } else {
        services.out.writeln(
          'runs: $runs  generatedTokens: $totalGenerated  '
          'evalMs: $totalEvalMs  '
          'tokensPerSecond: ${aggregate.toStringAsFixed(2)}',
        );
      }
      return ExitCodes.ok;
    } finally {
      if (loaded) {
        try {
          await engine.unload();
        } catch (_) {
          // Unloading is best-effort before disposal.
        }
      }
      try {
        await engine.dispose();
      } catch (_) {
        // Disposal is best-effort; the command result is already decided.
      }
    }
  }

  int _engineUnavailable(bool json) {
    const message = 'the native session is unavailable; pass --stub';
    services.err.writeln('error: engineUnavailable: $message');
    if (json) {
      services.out.writeln(
        jsonEncode(
          encodeFailed(
            0,
            '',
            InferenceFailure(
              (b) => b
                ..code = InferenceFailureCode.engineUnavailable
                ..message = message,
            ),
          ),
        ),
      );
    }
    return ExitCodes.failure;
  }

  int _reportFailure(
    InferenceFailure failure,
    int requestId,
    bool json, {
    String text = '',
  }) {
    services.err.writeln('error: ${failure.code.name}: ${failure.message}');
    if (json) {
      services.out.writeln(jsonEncode(encodeFailed(requestId, text, failure)));
    } else if (text.isNotEmpty) {
      services.out.writeln(text);
    }
    return ExitCodes.failure;
  }
}

final GenerationMetrics _zeroMetrics = GenerationMetrics(
  (b) => b
    ..promptTokenCount = 0
    ..generatedTokenCount = 0
    ..promptEvalMs = 0
    ..evalMs = 0,
);
