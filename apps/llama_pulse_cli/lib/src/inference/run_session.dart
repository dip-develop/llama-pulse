import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../exit_codes.dart';
import 'output_schema.dart';

/// How a generation session reports progress.
enum RunOutputMode {
  /// Human text on stdout, diagnostics on stderr.
  human,

  /// One JSON object per line on stdout.
  stream,

  /// Exactly one terminal JSON object on stdout.
  json,

  /// No output; used by `bench` to collect metrics only.
  quiet,
}

/// How a generation session ended.
enum SessionStatus { completed, cancelled, failed }

/// The result of consuming one generation stream to its terminal event.
final class SessionResult {
  /// Creates a result for [status] with the produced [text].
  const SessionResult({
    required this.status,
    required this.text,
    this.metrics,
    this.failure,
  });

  /// Terminal state.
  final SessionStatus status;

  /// Full or partial output text.
  final String text;

  /// Final metrics when the engine reported them.
  final GenerationMetrics? metrics;

  /// Failure payload for [SessionStatus.failed].
  final InferenceFailure? failure;

  /// Process exit code implied by [status].
  int get exitCode => switch (status) {
    SessionStatus.completed => ExitCodes.ok,
    SessionStatus.cancelled => ExitCodes.interrupted,
    SessionStatus.failed => ExitCodes.failure,
  };
}

/// Consumes [engine]'s stream for [request] until it terminates.
///
/// Output is written according to [mode]. A first [interrupts] event cancels
/// the request and a second event, or [cancelGrace] without a terminal, ends
/// the session as cancelled. The caller owns the engine lifecycle.
Future<SessionResult> runSession({
  required LlamaEngine engine,
  required GenerationRequest request,
  required StringSink out,
  required StringSink err,
  required RunOutputMode mode,
  Stream<ProcessSignal>? interrupts,
  Duration cancelGrace = const Duration(seconds: 5),
}) async {
  final requestId = request.requestId;
  final text = StringBuffer();
  final done = Completer<GenerationEvent>();
  GenerationMetrics? latestMetrics;
  Timer? graceTimer;
  var interrupted = false;

  void finish(GenerationEvent event) {
    if (!done.isCompleted) {
      done.complete(event);
    }
  }

  void emit(Map<String, Object?> event) {
    out.writeln(jsonEncode(event));
  }

  void onSignal(ProcessSignal signal) {
    if (interrupted) {
      finish(GenerationEvent.cancelled(requestId));
      return;
    }
    interrupted = true;
    if (mode != RunOutputMode.quiet) {
      err.writeln('cancelling...');
    }
    unawaited(engine.cancel(requestId));
    graceTimer = Timer(
      cancelGrace,
      () => finish(GenerationEvent.cancelled(requestId)),
    );
  }

  final signals = interrupts?.listen(onSignal);
  final events = engine
      .generate(request)
      .listen(
        (event) {
          switch (event.kind) {
            case GenerationEventKind.started:
              if (mode == RunOutputMode.stream) {
                emit(encodeStarted(requestId));
              }
            case GenerationEventKind.token:
              text.write(event.text);
              switch (mode) {
                case RunOutputMode.human:
                  out.write(event.text);
                case RunOutputMode.stream:
                  emit(encodeToken(requestId, event.text));
                case RunOutputMode.json:
                case RunOutputMode.quiet:
                  break;
              }
            case GenerationEventKind.metrics:
              final metrics = event.metrics;
              if (metrics != null) {
                latestMetrics = metrics;
                if (mode == RunOutputMode.stream) {
                  emit(encodeMetrics(requestId, metrics));
                }
              }
            case GenerationEventKind.completed:
              if (event.metrics != null) {
                latestMetrics = event.metrics;
              }
              finish(event);
            case GenerationEventKind.cancelled:
            case GenerationEventKind.failed:
              finish(event);
          }
        },
        onError: (Object error) {
          finish(
            GenerationEvent.failed(
              requestId,
              InferenceFailure(
                (b) => b
                  ..code = InferenceFailureCode.unknown
                  ..message = 'The generation stream failed.'
                  ..details = error.toString(),
              ),
            ),
          );
        },
        onDone: () => finish(
          GenerationEvent.failed(
            requestId,
            InferenceFailure(
              (b) => b
                ..code = InferenceFailureCode.unknown
                ..message = 'the engine stream ended without a result',
            ),
          ),
        ),
      );

  final terminal = await done.future;
  graceTimer?.cancel();
  await signals?.cancel();
  await events.cancel();

  final status = switch (terminal.kind) {
    GenerationEventKind.completed => SessionStatus.completed,
    GenerationEventKind.cancelled => SessionStatus.cancelled,
    GenerationEventKind.failed => SessionStatus.failed,
    _ => SessionStatus.failed,
  };
  final metrics = terminal.metrics ?? latestMetrics;
  final failure = terminal.failure;
  final partialText = text.toString();

  switch (mode) {
    case RunOutputMode.stream:
    case RunOutputMode.json:
      final line = switch (status) {
        SessionStatus.completed => encodeCompleted(
          requestId,
          partialText,
          metrics ?? _zeroMetrics,
        ),
        SessionStatus.cancelled => encodeCancelled(requestId, partialText),
        SessionStatus.failed => encodeFailed(
          requestId,
          partialText,
          failure ?? _unknownFailure,
        ),
      };
      emit(line);
    case RunOutputMode.human:
      if (status == SessionStatus.completed || partialText.isNotEmpty) {
        out.writeln();
      }
      switch (status) {
        case SessionStatus.completed:
          err.writeln(_humanSummary(metrics ?? _zeroMetrics));
        case SessionStatus.cancelled:
          err.writeln('cancelled');
        case SessionStatus.failed:
          final reason = failure ?? _unknownFailure;
          err.writeln('error: ${reason.code.name}: ${reason.message}');
      }
    case RunOutputMode.quiet:
      break;
  }

  return SessionResult(
    status: status,
    text: partialText,
    metrics: metrics,
    failure: failure,
  );
}

/// Formats the human completion summary line.
String _humanSummary(GenerationMetrics metrics) =>
    'tokens: ${metrics.generatedTokenCount}  '
    'tok/s: ${metrics.tokensPerSecond.toStringAsFixed(2)}  '
    'prompt ms: ${metrics.promptEvalMs}';

final GenerationMetrics _zeroMetrics = GenerationMetrics(
  (b) => b
    ..promptTokenCount = 0
    ..generatedTokenCount = 0
    ..promptEvalMs = 0
    ..evalMs = 0,
);

final InferenceFailure _unknownFailure = InferenceFailure(
  (b) => b
    ..code = InferenceFailureCode.unknown
    ..message = 'The generation failed.',
);
