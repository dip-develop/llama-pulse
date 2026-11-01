import 'package:args/args.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../params/params_options.dart';

/// Numeric and model-path overrides supplied on the command line.
final class InferenceOverrides {
  /// Creates overrides; a null field leaves the stored value untouched.
  const InferenceOverrides({
    this.modelPath,
    this.threads,
    this.temperature,
    this.topP,
    this.topK,
    this.maxTokens,
    this.contextSize,
    this.chatTemplate,
    this.useChatTemplate,
  });

  /// Replacement model path, or null to keep the stored one.
  final String? modelPath;

  /// Replacement thread count.
  final int? threads;

  /// Replacement sampling temperature.
  final double? temperature;

  /// Replacement nucleus sampling mass.
  final double? topP;

  /// Replacement top-k cutoff.
  final int? topK;

  /// Replacement generation token budget.
  final int? maxTokens;

  /// Replacement context window.
  final int? contextSize;

  /// Replacement chat template; `none` sends the raw prompt.
  final String? chatTemplate;

  /// Replacement templating switch; null keeps the stored value.
  final bool? useChatTemplate;

  /// Returns [params] with every non-null override applied.
  ModelParams applyTo(ModelParams params) => params.copyWith(
    modelPath: modelPath,
    threads: threads,
    temperature: temperature,
    topP: topP,
    topK: topK,
    maxTokens: maxTokens,
    contextSize: contextSize,
    chatTemplate: chatTemplate ?? params.chatTemplate,
    useChatTemplate: useChatTemplate ?? params.useChatTemplate,
  );
}

/// The parsed shared inference flags.
final class ParsedInferenceOptions {
  /// Creates a parse result; [errors] is empty when every value parsed.
  const ParsedInferenceOptions({
    required this.overrides,
    required this.errors,
    this.paramOverrides = const {},
    this.paramErrors = const [],
    this.libraryPath,
  });

  /// The accepted overrides.
  final InferenceOverrides overrides;

  /// One message per flag whose value was not a number.
  final List<String> errors;

  /// Catalog values supplied with `--param`, keyed by catalog id.
  final Map<String, String> paramOverrides;

  /// One message per `--param` argument that could not be parsed.
  final List<String> paramErrors;

  /// The `--lib` path, or null to let the worker resolve the library.
  final String? libraryPath;
}

/// Registers the flags shared by `run` and `bench` on [parser].
///
/// [maxTokensDefault] is set by `bench`; `run` leaves the flag unset so the
/// stored parameter wins.
void addInferenceOptions(ArgParser parser, {String? maxTokensDefault}) {
  addParamOption(parser);
  parser
    ..addOption('model', help: 'Path to the .gguf model file.')
    ..addOption('lib', help: 'Absolute path to the libllama shared library.')
    ..addOption('threads', help: 'Worker threads used for evaluation.')
    ..addOption('temperature', help: 'Sampling temperature.')
    ..addOption('top-p', help: 'Nucleus sampling probability mass.')
    ..addOption('top-k', help: 'Top-k sampling cutoff.')
    ..addOption('context-size', help: 'Context window, in tokens.')
    ..addOption(
      'chat-template',
      help: 'Built-in chat template name; "none" sends the raw prompt.',
    )
    ..addFlag(
      'use-chat-template',
      defaultsTo: true,
      help:
          'Wrap the prompt in a chat template (--no-use-chat-template sends '
          'the raw prompt).',
    );
  if (maxTokensDefault == null) {
    parser.addOption('max-tokens', help: 'Upper bound on generated tokens.');
  } else {
    parser.addOption(
      'max-tokens',
      defaultsTo: maxTokensDefault,
      help: 'Upper bound on generated tokens.',
    );
  }
}

/// Parses the shared inference flags, collecting non-numeric values.
ParsedInferenceOptions parseInferenceOptions(ArgResults args) {
  final errors = <String>[];

  int? readInt(String name) {
    final raw = args.option(name);
    if (raw == null) {
      return null;
    }
    final value = int.tryParse(raw);
    if (value == null) {
      errors.add("invalid value for --$name: '$raw'");
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
      errors.add("invalid value for --$name: '$raw'");
    }
    return value;
  }

  final paramArguments = parseParamArguments(args);

  return ParsedInferenceOptions(
    overrides: InferenceOverrides(
      modelPath: args.option('model'),
      threads: readInt('threads'),
      temperature: readDouble('temperature'),
      topP: readDouble('top-p'),
      topK: readInt('top-k'),
      maxTokens: readInt('max-tokens'),
      contextSize: readInt('context-size'),
      chatTemplate: args.option('chat-template'),
      useChatTemplate: args.wasParsed('use-chat-template')
          ? args.flag('use-chat-template')
          : null,
    ),
    errors: errors,
    paramOverrides: paramArguments.overrides,
    paramErrors: paramArguments.errors,
    libraryPath: args.option('lib'),
  );
}

/// Returns the canonical values of the typed flags supplied in [overrides].
///
/// Only ids with a typed [ModelParams] field and a shared inference flag are
/// included; they let `--param` detect a disagreement with the flag.
Map<String, String> typedInferenceValues(InferenceOverrides overrides) => {
  if (overrides.contextSize != null) 'ctx-size': '${overrides.contextSize}',
  if (overrides.threads != null) 'threads': '${overrides.threads}',
  if (overrides.temperature != null) 'temp': '${overrides.temperature}',
  if (overrides.topK != null) 'top-k': '${overrides.topK}',
  if (overrides.topP != null) 'top-p': '${overrides.topP}',
};

/// Returns the model path to use: the flag when given, else [storedPath].
///
/// Returns null when the resulting path is blank.
String? resolveModelPath(String? flagValue, String storedPath) {
  final path = flagValue ?? storedPath;
  return path.trim().isEmpty ? null : path;
}
