import '../../domain/entities/inference_failure.dart';
import '../../domain/entities/inference_failure_code.dart';

/// The upstream llama.cpp release this app binds against.
///
/// The pin is authoritative: the library found at runtime must report exactly
/// [version] from `llama_version()`.
abstract final class LlamaVersionPin {
  /// The release version a conforming library reports.
  static const String version = '0.8.0';

  /// The upstream git tag the vendored headers come from.
  static const String tag = 'v0.8.0';

  /// The upstream commit the tag points at.
  static const String commit = '8642541b255bfb5dc39cd351a178be09013a55d6';

  /// The oldest `llama-server` style build number this pin supports.
  static const int minimumBuildNumber = 4000;

  /// Whether [actual] is the pinned version, ignoring surrounding whitespace.
  static bool matches(String actual) => actual.trim() == version;

  /// A `libraryVersionMismatch` failure naming what the library reported.
  static InferenceFailure mismatch(String actual) => InferenceFailure(
    (b) => b
      ..code = InferenceFailureCode.libraryVersionMismatch
      ..message = 'expected llama.cpp $version, found "$actual"',
  );
}
