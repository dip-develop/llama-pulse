import '../entities/server_binary_info.dart';
import '../entities/server_config.dart';

/// Resolves the `llama-server` executable and reads its version.
///
/// Test seam: replaces the filesystem and version probe in supervisor tests.
abstract interface class ServerBinaryLocator {
  /// Resolves the executable for [config] without starting a server.
  ///
  /// Throws a `ServerException` with `binaryNotFound` or
  /// `binaryNotExecutable` when no runnable binary exists.
  Future<ServerBinaryInfo> locate(ServerConfig config);
}
