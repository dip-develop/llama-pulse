import 'dart:async';

import '../../domain/entities/generation_metrics.dart';
import '../../domain/entities/generation_request.dart';
import '../../domain/entities/inference_failure.dart';
import '../../domain/entities/inference_failure_code.dart';
import '../../domain/entities/model_params.dart';
import '../../domain/exceptions/inference_failure_exception.dart';
import '../../domain/gateways/llama_session.dart';

/// A deterministic [LlamaSession] used until the native engine lands.
///
/// It produces the same text for the same prompt and respects the configured
/// token cap, so the worker, CLI and GUI can be exercised without llama.cpp.
final class StubLlamaSession implements LlamaSession {
  /// Creates a stub that waits [tokenDelay] before each token.
  StubLlamaSession({this.tokenDelay = const Duration(milliseconds: 20)});

  /// Delay applied before each generated token.
  final Duration tokenDelay;

  static const _vocabulary = [
    'Local',
    ' models',
    ' run',
    ' on',
    ' your',
    ' machine',
    '.',
    ' No',
    ' cloud',
    ' needed',
  ];

  final _stopwatch = Stopwatch();

  String? _libraryPath;
  ModelParams? _params;
  GenerationRequest? _request;
  List<String> _tokens = const [];
  int _emitted = 0;
  bool _cancelled = false;
  bool _finished = false;
  bool _disposed = false;

  @override
  Future<void> open(String libraryPath) async {
    _libraryPath = libraryPath;
  }

  @override
  Future<void> load(ModelParams params) async {
    if (_libraryPath == null) {
      throw InferenceFailureException(
        InferenceFailure(
          (b) => b
            ..code = InferenceFailureCode.engineUnavailable
            ..message = 'The engine was not opened before loading a model.',
        ),
      );
    }
    if (params.modelPath.trim().isEmpty) {
      throw InferenceFailureException(
        InferenceFailure(
          (b) => b
            ..code = InferenceFailureCode.modelNotFound
            ..message = 'No model path configured.',
        ),
      );
    }
    _params = params;
    _reset();
  }

  @override
  void begin(GenerationRequest request) {
    final params = _params;
    if (params == null) {
      throw InferenceFailureException(
        InferenceFailure(
          (b) => b
            ..code = InferenceFailureCode.engineUnavailable
            ..message = 'No model is loaded.',
        ),
      );
    }
    _request = request;
    _tokens = _tokenize(request.prompt, params.maxTokens);
    _emitted = 0;
    _cancelled = false;
    _finished = false;
    _stopwatch
      ..reset()
      ..start();
  }

  @override
  Future<GenerationStep?> next() async {
    if (_disposed || _cancelled || _finished || _request == null) {
      return null;
    }
    await Future<void>.delayed(tokenDelay);
    if (_disposed || _cancelled) {
      return null;
    }
    final metrics = _metrics();
    if (_emitted < _tokens.length) {
      final token = _tokens[_emitted++];
      return GenerationStep(text: token, metrics: metrics);
    }
    _finished = true;
    _stopwatch.stop();
    return GenerationStep(metrics: metrics, done: true);
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
  }

  @override
  Future<void> unload() async {
    _params = null;
    _reset();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _params = null;
    _reset();
  }

  GenerationMetrics _metrics() {
    final prompt = _request?.prompt ?? '';
    final runes = prompt.runes.length;
    return GenerationMetrics(
      (b) => b
        ..promptTokenCount = runes < 4 ? 1 : runes ~/ 4
        ..generatedTokenCount = _emitted
        ..promptEvalMs = 3
        ..evalMs = _stopwatch.elapsedMilliseconds,
    );
  }

  List<String> _tokenize(String prompt, int maxTokens) {
    final weight = prompt.codeUnits.fold(0, (sum, unit) => sum + unit);
    final requested = 5 + weight % 8;
    final count = requested > maxTokens ? maxTokens : requested;
    return List.generate(
      count,
      (index) => _vocabulary[index % _vocabulary.length],
      growable: false,
    );
  }

  void _reset() {
    _request = null;
    _tokens = const [];
    _emitted = 0;
    _cancelled = false;
    _finished = false;
    _stopwatch
      ..stop()
      ..reset();
  }
}
