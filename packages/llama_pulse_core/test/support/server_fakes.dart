import 'dart:async';

import 'package:llama_pulse_core/llama_pulse_core.dart';

/// A [ServerProcess] driven entirely from a test.
final class FakeServerProcess implements ServerProcess {
  /// Creates a process that reports [pid].
  FakeServerProcess({this.pid = 4321});

  @override
  final int pid;

  final StreamController<String> _stdout = StreamController<String>.broadcast();
  final StreamController<String> _stderr = StreamController<String>.broadcast();
  final Completer<int> _exit = Completer<int>();

  /// Every kill request, in order.
  final List<ServerKillMode> kills = <ServerKillMode>[];

  /// Complete the exit future when a graceful kill arrives.
  bool exitOnGraceful = false;

  /// Complete the exit future when a force kill arrives.
  bool exitOnForce = false;

  /// Exit code reported by a kill-driven exit.
  int exitCodeValue = 0;

  @override
  Stream<String> get stdoutLines => _stdout.stream;

  @override
  Stream<String> get stderrLines => _stderr.stream;

  @override
  Future<int> get exitCode => _exit.future;

  /// Whether [exit] has been called or a kill completed the process.
  bool get hasExited => _exit.isCompleted;

  @override
  bool kill(ServerKillMode mode) {
    kills.add(mode);
    if (mode == ServerKillMode.graceful && exitOnGraceful) {
      exit(exitCodeValue);
    } else if (mode == ServerKillMode.force && exitOnForce) {
      exit(exitCodeValue);
    }
    return true;
  }

  /// Completes the exit future once.
  void exit(int code) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
    }
  }

  /// Emits one stdout line.
  void writeStdout(String line) {
    if (!_stdout.isClosed) {
      _stdout.add(line);
    }
  }

  /// Emits one stderr line.
  void writeStderr(String line) {
    if (!_stderr.isClosed) {
      _stderr.add(line);
    }
  }

  /// Closes both output streams.
  Future<void> close() async {
    await _stdout.close();
    await _stderr.close();
  }
}

/// A [ServerProcessLauncher] that records the request and returns a fake.
final class FakeLauncher implements ServerProcessLauncher {
  /// Process returned by [start], when [error] is null.
  FakeServerProcess? process;

  /// Error thrown by [start], when set.
  Object? error;

  /// When set, [start] waits for it before returning.
  Completer<void>? gate;

  /// Executable of the most recent launch.
  String? executable;

  /// Argument vector of the most recent launch.
  List<String>? arguments;

  /// Number of launch attempts.
  int calls = 0;

  @override
  Future<ServerProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
  }) async {
    calls++;
    this.executable = executable;
    this.arguments = List<String>.of(arguments);
    final waiting = gate;
    if (waiting != null) {
      await waiting.future;
    }
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    final fake = process;
    if (fake == null) {
      throw StateError('no fake process configured');
    }
    return fake;
  }
}

/// One request seen by [FakeHttpClient].
final class HttpRequestRecord {
  /// Creates a record.
  const HttpRequestRecord(this.uri, this.headers);

  /// Requested URI.
  final Uri uri;

  /// Headers sent with the request.
  final Map<String, String> headers;
}

/// A [ServerHttpClient] answering from a map of canned responses.
final class FakeHttpClient implements ServerHttpClient {
  /// Responses per URI path; the last entry is reused once the queue drains.
  final Map<String, List<Object>> responses = <String, List<Object>>{};

  /// Every request, in order.
  final List<HttpRequestRecord> requests = <HttpRequestRecord>[];

  /// Whether [close] was called.
  bool closed = false;

  /// Queues [response] for [path]; a [ServerHttpResponse] is returned and any
  /// other object is thrown.
  void addResponse(String path, Object response) {
    responses.putIfAbsent(path, () => <Object>[]).add(response);
  }

  /// Request paths in call order.
  List<String> get paths => <String>[
    for (final request in requests) request.uri.path,
  ];

  @override
  Future<ServerHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    requests.add(HttpRequestRecord(uri, Map<String, String>.of(headers)));
    final queue = responses[uri.path];
    if (queue == null || queue.isEmpty) {
      throw StateError('no fake response for ${uri.path}');
    }
    final value = queue.length > 1 ? queue.removeAt(0) : queue.first;
    if (value is Future<ServerHttpResponse>) {
      return value;
    }
    if (value is ServerHttpResponse) {
      return value;
    }
    if (value is Exception) {
      throw value;
    }
    throw StateError('unsupported fake response: $value');
  }

  @override
  void close() {
    closed = true;
  }
}

/// A [PortProbe] with a configurable answer.
final class FakePortProbe implements PortProbe {
  /// Answer returned by [isAvailable].
  bool available = true;

  /// Every probe, in order.
  final List<(String, int)> calls = <(String, int)>[];

  @override
  Future<bool> isAvailable(String host, int port) async {
    calls.add((host, port));
    return available;
  }
}

/// A [ServerStateRepository] backed by a list.
final class FakeStateRepository implements ServerStateRepository {
  /// State returned by [load].
  ServerState? stored;

  /// Every state passed to a successful [save].
  final List<ServerState> saved = <ServerState>[];

  /// When set, [save] throws it and records nothing.
  Object? saveError;

  /// Number of [clear] calls.
  int clearCalls = 0;

  @override
  Future<ServerState?> load() async => stored;

  @override
  Future<void> save(ServerState state) async {
    final failure = saveError;
    if (failure != null) {
      throw failure;
    }
    stored = state;
    saved.add(state);
  }

  @override
  Future<void> clear() async {
    stored = null;
    clearCalls++;
  }
}

/// A [ServerBinaryLocator] with a configurable answer.
final class FakeBinaryLocator implements ServerBinaryLocator {
  /// Info returned by [locate].
  ServerBinaryInfo? info;

  /// When set, [locate] throws it.
  Object? error;

  /// Every configuration passed to [locate].
  final List<ServerConfig> configs = <ServerConfig>[];

  @override
  Future<ServerBinaryInfo> locate(ServerConfig config) async {
    configs.add(config);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    final value = info;
    if (value == null) {
      throw StateError('no fake binary configured');
    }
    return value;
  }
}

/// A [ProcessSignaller] that records every request.
final class FakeProcessSignaller implements ProcessSignaller {
  /// Every signal, in order.
  final List<(int, ServerKillMode)> sends = <(int, ServerKillMode)>[];

  /// Answer returned by [send].
  bool result = true;

  @override
  bool send(int pid, ServerKillMode mode) {
    sends.add((pid, mode));
    return result;
  }
}

/// A [ProcessExecutor] returning canned output.
final class FakeProcessExecutor implements ProcessExecutor {
  /// Creates an executor returning [output].
  FakeProcessExecutor({
    this.output = const ProcessOutput(exitCode: 0, stdout: '', stderr: ''),
  });

  /// Output returned by [run].
  ProcessOutput output;

  /// Every invocation, in order.
  final List<ExecutorInvocation> invocations = <ExecutorInvocation>[];

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    invocations.add(ExecutorInvocation(executable, arguments));
    return output;
  }
}

/// One [FakeProcessExecutor] invocation.
final class ExecutorInvocation {
  /// Creates an invocation.
  const ExecutorInvocation(this.executable, this.arguments);

  /// Executable that was run.
  final String executable;

  /// Arguments that were passed.
  final List<String> arguments;
}
