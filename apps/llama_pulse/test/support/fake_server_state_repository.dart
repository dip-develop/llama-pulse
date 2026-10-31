import 'package:llama_pulse_core/llama_pulse_core.dart';

/// A [ServerStateRepository] that keeps the document in memory for the test.
final class FakeServerStateRepository implements ServerStateRepository {
  /// Creates a repository that reports [recorded] until a test replaces it.
  FakeServerStateRepository({this.recorded});

  /// Document returned by [load], or `null` when nothing is stored.
  ServerState? recorded;

  /// Number of times [load] was called.
  int loadCalls = 0;

  /// Number of times [save] was called.
  int saveCalls = 0;

  @override
  Future<ServerState?> load() async {
    loadCalls++;
    return recorded;
  }

  @override
  Future<void> save(ServerState state) async {
    saveCalls++;
    recorded = state;
  }

  @override
  Future<void> clear() async {
    recorded = null;
  }
}
