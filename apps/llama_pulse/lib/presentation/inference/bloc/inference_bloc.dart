import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import 'inference_event.dart';
import 'inference_state.dart';
import 'inference_status.dart';

/// Drives the inference screen: parameters, model loading and generation.
///
/// The engine is optional because a production build may ship without the
/// native library; without it, loading and generating report
/// [InferenceFailureCode.engineUnavailable] instead of throwing.
class InferenceBloc extends Bloc<InferenceEvent, InferenceState> {
  /// Creates the bloc over the parameter use cases and an optional engine.
  InferenceBloc(
    this._loadParams,
    this._saveParams,
    this._validator,
    this._engine,
  ) : super(InferenceState.initial()) {
    on<InferenceStarted>(_onStarted);
    on<InferenceParamsChanged>(_onParamsChanged);
    on<InferenceParamChanged>(_onParamChanged);
    on<InferenceParamsReset>(_onParamsReset);
    on<InferencePromptChanged>(_onPromptChanged);
    on<InferenceSaveRequested>(_onSaveRequested);
    on<InferenceLoadRequested>(_onLoadRequested);
    on<InferenceGenerateRequested>(_onGenerateRequested);
    on<InferenceCancelRequested>(_onCancelRequested);
    on<InferenceUnloadRequested>(_onUnloadRequested);
    on<InferenceConversationCleared>(_onConversationCleared);
    on<InferenceEngineEventReceived>(_onEngineEvent);
    on<InferenceEngineStreamEnded>(_onEngineStreamEnded);
  }

  /// Keeps only the newest entries so a long run cannot grow without bound.
  static const int _maxMetricsHistory = 100;

  final LoadModelParams _loadParams;
  final SaveModelParams _saveParams;
  final ModelParamsValidator _validator;
  final LlamaEngine? _engine;

  StreamSubscription<GenerationEvent>? _subscription;
  Stopwatch? _stopwatch;
  int _requestCounter = 0;
  bool _terminalSeen = false;
  bool _cancelRequested = false;
  bool _userEdited = false;

  Future<void> _onStarted(
    InferenceStarted event,
    Emitter<InferenceState> emit,
  ) async {
    try {
      final ModelParams params = await _loadParams();
      // The stored document must not overwrite an input the user already
      // touched, nor a state that moved past `initial` while loading.
      if (_userEdited || state.status != InferenceStatus.initial) {
        return;
      }
      _emit(emit, state.rebuild((b) => b..params.replace(params)));
    } on Object catch (error) {
      _reportUnexpected(emit, error, 'Could not load the stored parameters.');
    }
  }

  void _onParamsChanged(
    InferenceParamsChanged event,
    Emitter<InferenceState> emit,
  ) {
    _userEdited = true;
    _emit(emit, state.rebuild((b) => b..params.replace(event.params)));
  }

  void _onParamChanged(
    InferenceParamChanged event,
    Emitter<InferenceState> emit,
  ) {
    _userEdited = true;
    final ModelParams next = _writeParam(state.params, event.id, event.value);
    if (next == state.params) {
      return;
    }
    _emit(emit, state.rebuild((b) => b..params.replace(next)));
  }

  void _onParamsReset(
    InferenceParamsReset event,
    Emitter<InferenceState> emit,
  ) {
    if (event.ids.isEmpty) {
      return;
    }
    _userEdited = true;
    var next = state.params;
    for (final String id in event.ids) {
      next = _resetParam(next, id);
    }
    _emit(emit, state.rebuild((b) => b..params.replace(next)));
  }

  /// Writes [value] for [id], using the typed field when one exists.
  ///
  /// A typed field is authoritative, so a stale catalog entry for the same id
  /// is dropped. Unknown or map-backed ids go through [ParameterValues.set].
  ModelParams _writeParam(ModelParams params, String id, String? value) {
    final ModelParams? typed = switch (id) {
      'ctx-size' => _writeInt(
        params,
        value,
        ModelParams.defaults().contextSize,
        (p, v) => p.copyWith(contextSize: v),
      ),
      'threads' => _writeInt(
        params,
        value,
        ModelParams.defaults().threads,
        (p, v) => p.copyWith(threads: v),
      ),
      'gpu-layers' => _writeInt(
        params,
        value,
        ModelParams.defaults().gpuLayers,
        (p, v) => p.copyWith(gpuLayers: v),
      ),
      'temp' => _writeDouble(
        params,
        value,
        ModelParams.defaults().temperature,
        (p, v) => p.copyWith(temperature: v),
      ),
      'top-k' => _writeInt(
        params,
        value,
        ModelParams.defaults().topK,
        (p, v) => p.copyWith(topK: v),
      ),
      'top-p' => _writeDouble(
        params,
        value,
        ModelParams.defaults().topP,
        (p, v) => p.copyWith(topP: v),
      ),
      'chat-template' => params.copyWith(
        chatTemplate: value == null || value.isEmpty ? null : value,
      ),
      _ => null,
    };
    if (typed == null) {
      return params.copyWith(
        params: ParameterValues.set(params.params, id, value),
      );
    }
    return typed.copyWith(params: ParameterValues.remove(typed.params, id));
  }

  /// Clears [id], returning a typed field to the [ModelParams.defaults] value.
  ModelParams _resetParam(ModelParams params, String id) =>
      _writeParam(params, id, null);

  /// Applies [value] to an integer field, or the default when it is null.
  ///
  /// Invalid text is ignored: the row validates before dispatching, so this is
  /// only a guard for a programmatic caller.
  ModelParams _writeInt(
    ModelParams params,
    String? value,
    int fallback,
    ModelParams Function(ModelParams params, int value) apply,
  ) {
    final int? parsed = value == null ? fallback : int.tryParse(value.trim());
    return parsed == null ? params : apply(params, parsed);
  }

  /// Applies [value] to a double field, or the default when it is null.
  ModelParams _writeDouble(
    ModelParams params,
    String? value,
    double fallback,
    ModelParams Function(ModelParams params, double value) apply,
  ) {
    final double? parsed = value == null
        ? fallback
        : double.tryParse(value.trim());
    return parsed == null ? params : apply(params, parsed);
  }

  void _onPromptChanged(
    InferencePromptChanged event,
    Emitter<InferenceState> emit,
  ) {
    _userEdited = true;
    _emit(emit, state.rebuild((b) => b..prompt = event.prompt));
  }

  Future<void> _onSaveRequested(
    InferenceSaveRequested event,
    Emitter<InferenceState> emit,
  ) async {
    final List<String> violations = _validator.validate(state.params);
    if (violations.isNotEmpty) {
      _emit(
        emit,
        _failed(InferenceFailureCode.invalidParams, violations.join('; ')),
      );
      return;
    }
    try {
      await _saveParams(state.params);
      _emit(emit, state.rebuild((b) => b..failure = null));
    } on Object catch (error) {
      _reportUnexpected(emit, error, 'Could not save the parameters.');
    }
  }

  Future<void> _onLoadRequested(
    InferenceLoadRequested event,
    Emitter<InferenceState> emit,
  ) async {
    _userEdited = true;
    final List<String> violations = _validator.validate(state.params);
    if (violations.isNotEmpty) {
      _emit(
        emit,
        _failed(InferenceFailureCode.invalidParams, violations.join('; ')),
      );
      return;
    }
    if (state.params.modelPath.trim().isEmpty) {
      _emit(
        emit,
        _failed(InferenceFailureCode.invalidParams, 'modelPath is required'),
      );
      return;
    }
    final LlamaEngine? engine = _engine;
    if (engine == null) {
      _emit(
        emit,
        _failed(InferenceFailureCode.engineUnavailable, 'no inference engine'),
      );
      return;
    }

    _emit(
      emit,
      state.rebuild(
        (b) => b
          ..status = InferenceStatus.loadingModel
          ..failure = null,
      ),
    );
    try {
      await engine.load(state.params);
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..status = InferenceStatus.modelReady
            ..failure = null,
        ),
      );
    } on InferenceFailureException catch (exception) {
      // Keep the whole failure so the banner can show the searched paths that
      // the locator put in `details`.
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..status = InferenceStatus.failure
            ..failure.replace(exception.failure),
        ),
      );
    } on Object catch (error) {
      _reportUnexpected(emit, error, 'Could not load the model.');
    }
  }

  Future<void> _onGenerateRequested(
    InferenceGenerateRequested event,
    Emitter<InferenceState> emit,
  ) async {
    final LlamaEngine? engine = _engine;
    if (engine == null) {
      _emit(
        emit,
        _failed(InferenceFailureCode.engineUnavailable, 'no inference engine'),
      );
      return;
    }
    final List<String> violations = _validator.validate(state.params);
    if (violations.isNotEmpty) {
      _emit(
        emit,
        _failed(InferenceFailureCode.invalidParams, violations.join('; ')),
      );
      return;
    }
    if (state.prompt.trim().isEmpty) {
      _emit(
        emit,
        _failed(InferenceFailureCode.invalidParams, 'prompt is required'),
      );
      return;
    }
    if (state.status != InferenceStatus.modelReady) {
      _emit(
        emit,
        _failed(InferenceFailureCode.engineBusy, 'the model is not ready'),
      );
      return;
    }

    final int requestId = ++_requestCounter;
    _terminalSeen = false;
    _cancelRequested = false;
    _stopwatch = Stopwatch()..start();

    final String text = state.prompt;
    final ChatMessage userMessage = ChatMessage.create(
      role: ChatMessage.roleUser,
      content: text,
    );
    // A non-empty list suppresses the engine's `prompt`-as-user fallback, so
    // the user turn is always present explicitly and never a system-only list.
    final String? systemPrompt = state.params.systemPrompt;
    final List<ChatMessage> messages = <ChatMessage>[
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        ChatMessage.create(role: ChatMessage.roleSystem, content: systemPrompt),
      ...state.transcript,
      userMessage,
    ];

    _emit(
      emit,
      state.rebuild(
        (b) => b
          ..status = InferenceStatus.generating
          ..activeRequestId = requestId
          ..failure = null
          ..timeToFirstTokenMs = null
          ..outputChunks = ListBuilder<String>()
          ..metricsHistory = ListBuilder<GenerationMetrics>()
          // The prompt stays in the composer: `PromptEditor` only syncs an
          // unfocused field, so clearing the state would desync the visible
          // text from it.
          ..transcript.add(userMessage),
      ),
    );

    final StreamSubscription<GenerationEvent>? previous = _subscription;
    try {
      final Stream<GenerationEvent> events = engine.generate(
        GenerationRequest.create(
          requestId: requestId,
          prompt: text,
          messages: messages,
          params: state.params,
        ),
      );
      _subscription = events.listen(
        (GenerationEvent generationEvent) =>
            _addEngineEvent(InferenceEngineEventReceived(generationEvent)),
        onError: (Object error, StackTrace stack) => _addEngineEvent(
          InferenceEngineStreamEnded(requestId, error: error),
        ),
        onDone: () => _addEngineEvent(InferenceEngineStreamEnded(requestId)),
      );
    } on Object catch (error) {
      _finishWithFailure(emit, InferenceFailureCode.unknown, '$error');
      return;
    }
    await previous?.cancel();
  }

  Future<void> _onCancelRequested(
    InferenceCancelRequested event,
    Emitter<InferenceState> emit,
  ) async {
    final LlamaEngine? engine = _engine;
    final int? requestId = state.activeRequestId;
    if (engine == null || requestId == null) {
      return;
    }
    if (state.status != InferenceStatus.generating) {
      return;
    }

    _cancelRequested = true;
    _emit(emit, state.rebuild((b) => b..status = InferenceStatus.cancelling));
    try {
      await engine.cancel(requestId);
    } on Object catch (error) {
      _reportUnexpected(emit, error, 'Could not cancel the generation.');
    }
  }

  Future<void> _onUnloadRequested(
    InferenceUnloadRequested event,
    Emitter<InferenceState> emit,
  ) async {
    if (state.status == InferenceStatus.generating ||
        state.status == InferenceStatus.cancelling) {
      // The worker rejects an unload while a request is in flight with
      // `engineBusy`; report that and leave the generation untouched.
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..failure.replace(
              InferenceFailure(
                (f) => f
                  ..code = InferenceFailureCode.engineBusy
                  ..message = 'cancel the running generation first',
              ),
            ),
        ),
      );
      return;
    }
    try {
      await _engine?.unload();
    } on Object catch (error) {
      _reportUnexpected(emit, error, 'Could not unload the model.');
      return;
    }
    _emit(
      emit,
      state.rebuild(
        (b) => b
          ..status = InferenceStatus.initial
          ..activeRequestId = null
          ..failure = null,
      ),
    );
  }

  void _onConversationCleared(
    InferenceConversationCleared event,
    Emitter<InferenceState> emit,
  ) {
    if (state.status == InferenceStatus.generating ||
        state.status == InferenceStatus.cancelling) {
      // The running turn still has to land; a clear during generation would
      // race its assistant reply into an already emptied transcript.
      return;
    }
    _emit(
      emit,
      state.rebuild((b) => b..transcript = ListBuilder<ChatMessage>()),
    );
  }

  void _onEngineEvent(
    InferenceEngineEventReceived event,
    Emitter<InferenceState> emit,
  ) {
    try {
      _applyEngineEvent(event.event, emit);
    } on Object catch (error) {
      _finishWithFailure(emit, InferenceFailureCode.unknown, '$error');
    }
  }

  void _applyEngineEvent(
    GenerationEvent generationEvent,
    Emitter<InferenceState> emit,
  ) {
    if (_terminalSeen || state.activeRequestId != generationEvent.requestId) {
      return;
    }

    switch (generationEvent.kind) {
      case GenerationEventKind.started:
        break;
      case GenerationEventKind.token:
        _emit(
          emit,
          state.rebuild(
            (b) => b
              ..outputChunks.add(generationEvent.text)
              ..timeToFirstTokenMs =
                  state.timeToFirstTokenMs ?? _stopwatch?.elapsedMilliseconds,
          ),
        );
      case GenerationEventKind.metrics:
        final GenerationMetrics? metrics = generationEvent.metrics;
        if (metrics != null) {
          _emit(
            emit,
            state.rebuild((b) => _appendMetrics(b.metricsHistory, metrics)),
          );
        }
      case GenerationEventKind.completed:
        final GenerationMetrics? metrics = generationEvent.metrics;
        _finish(
          emit,
          state.rebuild((b) {
            b
              ..status = InferenceStatus.modelReady
              ..activeRequestId = null;
            if (metrics != null) {
              _appendMetrics(b.metricsHistory, metrics);
            }
          }),
        );
      case GenerationEventKind.cancelled:
        final InferenceFailure? failure = _cancelRequested
            ? InferenceFailure(
                (b) => b
                  ..code = InferenceFailureCode.cancelled
                  ..message = 'generation cancelled',
              )
            : null;
        _finish(
          emit,
          state.rebuild((b) {
            b
              ..status = InferenceStatus.modelReady
              ..activeRequestId = null
              ..failure = null;
            if (failure != null) {
              b.failure.replace(failure);
            }
          }),
        );
      case GenerationEventKind.failed:
        final InferenceFailure failure =
            generationEvent.failure ??
            InferenceFailure(
              (b) => b
                ..code = InferenceFailureCode.unknown
                ..message = 'the engine reported a failure',
            );
        _finishWithFailure(emit, failure.code, failure.message);
    }
  }

  void _onEngineStreamEnded(
    InferenceEngineStreamEnded event,
    Emitter<InferenceState> emit,
  ) {
    if (_terminalSeen || state.activeRequestId != event.requestId) {
      return;
    }
    final Object? error = event.error;
    _finishWithFailure(
      emit,
      InferenceFailureCode.unknown,
      error == null
          ? 'the engine closed the stream without a terminal event'
          : '$error',
    );
  }

  void _appendMetrics(
    ListBuilder<GenerationMetrics> history,
    GenerationMetrics metrics,
  ) {
    history.add(metrics);
    if (history.length > _maxMetricsHistory) {
      history.replace(
        history.build().sublist(history.length - _maxMetricsHistory),
      );
    }
  }

  void _finish(Emitter<InferenceState> emit, InferenceState next) {
    _terminalSeen = true;
    _cancelRequested = false;
    unawaited(_cancelSubscription());
    _emit(emit, _commitDraft(next));
  }

  /// Folds the in-flight assistant draft into the transcript.
  ///
  /// Returns [next] unchanged when no text arrived, so a turn that failed
  /// before its first token — or that only produced zero-length tokens —
  /// leaves only the user message. Every terminal path goes through [_finish],
  /// and [_terminalSeen] makes that happen once.
  InferenceState _commitDraft(InferenceState next) {
    final String reply = next.output;
    if (reply.isEmpty) {
      return next;
    }
    return next.rebuild(
      (b) => b
        ..transcript.add(
          ChatMessage.create(role: ChatMessage.roleAssistant, content: reply),
        )
        ..outputChunks = ListBuilder<String>(),
    );
  }

  void _finishWithFailure(
    Emitter<InferenceState> emit,
    InferenceFailureCode code,
    String message,
  ) {
    if (_terminalSeen) {
      return;
    }
    _finish(
      emit,
      state.rebuild(
        (b) => b
          ..status = InferenceStatus.failure
          ..activeRequestId = null
          ..failure.replace(
            InferenceFailure(
              (f) => f
                ..code = code
                ..message = message,
            ),
          ),
      ),
    );
  }

  void _addEngineEvent(InferenceEvent event) {
    if (isClosed || _terminalSeen) {
      return;
    }
    add(event);
  }

  Future<void> _cancelSubscription() async {
    final StreamSubscription<GenerationEvent>? subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  InferenceState _failed(InferenceFailureCode code, String message) =>
      state.rebuild(
        (b) => b
          ..status = InferenceStatus.failure
          ..failure.replace(
            InferenceFailure(
              (f) => f
                ..code = code
                ..message = message,
            ),
          ),
      );

  void _reportUnexpected(
    Emitter<InferenceState> emit,
    Object error,
    String message,
  ) {
    _emit(emit, _failed(InferenceFailureCode.unknown, '$message $error'));
  }

  void _emit(Emitter<InferenceState> emit, InferenceState next) {
    if (isClosed) {
      return;
    }
    emit(next);
  }

  @override
  Future<void> close() async {
    final int? activeRequestId = state.activeRequestId;
    final bool wasGenerating =
        state.status == InferenceStatus.generating ||
        state.status == InferenceStatus.cancelling;
    _terminalSeen = true;
    _cancelRequested = false;
    await _cancelSubscription();
    if (wasGenerating && activeRequestId != null) {
      try {
        await _engine?.cancel(activeRequestId);
      } on Object catch (_) {
        // The engine is torn down with the app; nothing useful to report.
      }
    }
    return super.close();
  }
}
