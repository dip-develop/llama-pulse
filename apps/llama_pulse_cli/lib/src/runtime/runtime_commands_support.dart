import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../exit_codes.dart';

/// Maps a download or verification failure to the CLI exit code contract.
///
/// `4` means the payload was fetched but is not the pinned archive; `5` means
/// the transfer itself failed. Everything else is an unexpected failure (`1`)
/// except cancellation, which the caller reports as `130`.
int exitCodeForRuntimeFailure(RuntimeFailureCode code) => switch (code) {
  RuntimeFailureCode.network ||
  RuntimeFailureCode.httpStatus => ExitCodes.network,
  RuntimeFailureCode.checksumMismatch ||
  RuntimeFailureCode.sizeMismatch ||
  RuntimeFailureCode.extraction ||
  RuntimeFailureCode.unsafeArchive ||
  RuntimeFailureCode.manifest => ExitCodes.integrity,
  RuntimeFailureCode.cancelled => ExitCodes.interrupted,
  RuntimeFailureCode.diskSpace ||
  RuntimeFailureCode.unknown => ExitCodes.failure,
};

/// Resolves `--backend` against the pinned matrix.
///
/// Returns null for an unknown id; the caller turns that into a usage error.
RuntimeBackend? parseRuntimeBackend(String id) => RuntimeBackend.fromId(id);

/// The archive for [backend] on [platform], or null when the release has none.
RuntimeAsset? runtimeAssetFor(
  RuntimeRelease release,
  RuntimeBackend backend,
  RuntimePlatform platform,
) => release.forBackend(backend, platform);
