import 'package:args/args.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

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

  /// Returns [params] with every non-null override applied.
  ModelParams applyTo(ModelParams params) => params.copyWith(
    modelPath: modelPath,
    threads: threads,
    temperature: temperature,
    topP: topP,
    topK: topK,
    maxTokens: maxTokens,
    contextSize: contextSize,
  );
}

/// The parsed shared inference flags.
final class ParsedInferenceOptions {
  /// Creates a parse result; [errors] is empty when every value parsed.
  const ParsedInferenceOptions({required this.overrides, required this.errors});

  /// The accepted overrides.
  final InferenceOverrides overrides;

  /// One message per flag whose value was not a number.
  final List<String> errors;
}

/// Registers the flags shared by `run` and `bench` on [parser].
///
/// [maxTokensDefault] is set by `bench`; `run` leaves the flag unset so the
/// stored parameter wins.
void addInferenceOptions(ArgParser parser, {String? maxTokensDefault}) {
  parser
    ..addOption('model', help: 'Path to the .gguf model file.')
    ..addOption('threads', help: 'Worker threads used for evaluation.')
    ..addOption('temperature', help: 'Sampling temperature.')
    ..addOption('top-p', help: 'Nucleus sampling probability mass.')
    ..addOption('top-k', help: 'Top-k sampling cutoff.')
    ..addOption('context-size', help: 'Context window, in tokens.');
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

  return ParsedInferenceOptions(
    overrides: InferenceOverrides(
      modelPath: args.option('model'),
      threads: readInt('threads'),
      temperature: readDouble('temperature'),
      topP: readDouble('top-p'),
      topK: readInt('top-k'),
      maxTokens: readInt('max-tokens'),
      contextSize: readInt('context-size'),
    ),
    errors: errors,
  );
}

/// Returns the model path to use: the flag when given, else [storedPath].
///
/// Returns null when the resulting path is blank.
String? resolveModelPath(String? flagValue, String storedPath) {
  final path = flagValue ?? storedPath;
  return path.trim().isEmpty ? null : path;
}
