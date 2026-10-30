import 'dart:async';
import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../server/server_options.dart';
import '../server/server_output.dart';
import '../server/server_status_reader.dart';

/// Supervises one `llama-server` process in the foreground.
///
/// The command never daemonizes: it stays attached to the child, mirrors its
/// output and stops it on SIGINT or SIGTERM. `server-state.yaml` is written by
/// the supervisor, not by this command.
///
/// `--json` is NDJSON on stdout. Every failure that happens before the
/// controller publishes anything is reported as one `failed` object, so a
/// consumer always sees exactly one terminal line.
final class ServeCommand extends LlamaPulseCommand {
  /// Creates the command.
  ServeCommand(super.services) {
    addServerOptionFlags(argParser);
  }

  @override
  String get name => 'serve';

  @override
  String get description =>
      'Start and supervise llama-server in the foreground.';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final parsed = parseServerOptions(parsedArgs);
    final json = parsed.json;
    if (parsed.errors.isNotEmpty) {
      return _failPreStart(
        json: json,
        failure: _invalidConfig(parsed.errors),
        exitCode: ExitCodes.usage,
      );
    }

    final stored = await services.serverConfigRepository.load();
    final config = parsed.overrides.applyTo(stored);
    final violations = const ServerConfigValidator().validateForStart(config);
    if (violations.isNotEmpty) {
      return _failPreStart(
        json: json,
        failure: _invalidConfig(violations),
        exitCode: ExitCodes.usage,
      );
    }

    final model = File(config.modelPath);
    final modelIsFile =
        await model.exists() &&
        (await model.stat()).type == FileSystemEntityType.file;
    if (!modelIsFile) {
      return _failPreStart(
        json: json,
        failure: ServerFailure(
          (b) => b
            ..code = ServerFailureCode.modelNotFound
            ..message = 'model file not found: ${config.modelPath}',
        ),
        exitCode: ExitCodes.notFound,
      );
    }

    final controller = services.createServerController();
    StreamSubscription<ServerState>? statesSubscription;
    StreamSubscription<ServerMetrics>? metricsSubscription;
    StreamSubscription<ServerLogEntry>? logsSubscription;
    StreamSubscription<ProcessSignal>? signalSubscription;
    final done = Completer<void>();
    try {
      if (await ServerStatusReader(
        stateRepository: services.serverStateRepository,
        configRepository: services.serverConfigRepository,
        controller: controller,
      ).recordedServerAnswers()) {
        return _failPreStart(
          json: json,
          failure: ServerFailure(
            (b) => b
              ..code = ServerFailureCode.invalidConfig
              ..message = 'a server is already recorded; run llamapulse stop',
          ),
          exitCode: ExitCodes.failure,
        );
      }

      final ServerBinaryInfo binary;
      try {
        binary = await controller.locateBinary(config);
      } on ServerException catch (error) {
        return _failPreStart(
          json: json,
          failure: error.failure,
          exitCode: _exitFor(error.failure.code),
        );
      } catch (error) {
        return _failPreStart(
          json: json,
          failure: ServerFailure(
            (b) => b
              ..code = ServerFailureCode.binaryNotFound
              ..message = 'llama-server not found'
              ..details = '$error',
          ),
          exitCode: ExitCodes.failure,
        );
      }

      final started = Stopwatch()..start();
      var startingEmitted = false;
      var readyEmitted = false;
      var stoppingEmitted = false;
      var failedEmitted = false;
      var stopRequested = false;
      var startReturned = false;
      var terminalSeen = false;
      var terminalExit = ExitCodes.ok;

      void emit(Map<String, Object?> event) =>
          writeJsonLine(services.out, event);

      void finish() {
        if (!done.isCompleted) {
          done.complete();
        }
      }

      void emitStarting(ServerState state) {
        if (startingEmitted) {
          return;
        }
        startingEmitted = true;
        if (json) {
          emit(
            encodeServeStarting(
              supervisorPid: state.supervisorPid,
              modelPath: config.modelPath,
              host: config.host,
              port: config.port,
              binaryPath: binary.path,
              binaryVersion: binary.version,
            ),
          );
        }
      }

      void emitReady(ServerState state) {
        if (readyEmitted) {
          return;
        }
        readyEmitted = true;
        if (json) {
          emit(
            encodeServeReady(
              serverPid: state.serverPid,
              baseUrl: state.baseUrl,
              startupMs: started.elapsedMilliseconds,
            ),
          );
        }
      }

      void emitStopping(String reason) {
        if (stoppingEmitted) {
          return;
        }
        stoppingEmitted = true;
        if (json) {
          emit(encodeServeStopping(reason));
        } else {
          services.err.writeln(
            reason == 'sigint' ? 'cancelling...' : 'stopping...',
          );
        }
      }

      void fail(ServerFailure failure, int? lastExitCode) {
        if (done.isCompleted) {
          return;
        }
        if (!failedEmitted) {
          failedEmitted = true;
          if (json) {
            emit(encodeServeFailed(failure, lastExitCode));
          }
          _printFailure(failure);
        }
        finish();
      }

      void failWith(ServerFailureCode code, String message, {String? details}) {
        terminalExit = _exitFor(code);
        fail(
          ServerFailure(
            (b) => b
              ..code = code
              ..message = message
              ..details = details,
          ),
          null,
        );
      }

      Future<void> requestStop(
        String reason, {
        required bool duringStart,
      }) async {
        if (stopRequested || done.isCompleted) {
          return;
        }
        stopRequested = true;
        terminalExit = reason == 'sigint'
            ? ExitCodes.interrupted
            : ExitCodes.ok;
        emitStopping(reason);
        try {
          await controller.stop();
        } on ServerException catch (error) {
          terminalExit = ExitCodes.failure;
          fail(error.failure, null);
          return;
        } catch (error) {
          failWith(
            ServerFailureCode.unknown,
            'could not stop llama-server',
            details: '$error',
          );
          return;
        }
        // `stop()` waits for an in-flight start, so the controller has settled
        // even when no terminal state reached the stream listener.
        if (duringStart) {
          finish();
        }
      }

      // The subscriptions must exist before `start` so the `starting` event and
      // the first child log lines are never missed.
      statesSubscription = controller.states.listen(
        (state) {
          if (done.isCompleted) {
            return;
          }
          switch (state.phase) {
            case ServerPhase.starting:
              emitStarting(state);
            case ServerPhase.running:
              emitStarting(state);
              emitReady(state);
            case ServerPhase.stopping:
              if (!stopRequested && !failedEmitted) {
                stopRequested = true;
                emitStopping('child-exit');
              }
            case ServerPhase.stopped:
              terminalSeen = true;
              if (json) {
                emit(encodeServeStopped(state.lastExitCode ?? 0));
              }
              finish();
            case ServerPhase.failed:
              terminalSeen = true;
              terminalExit = ExitCodes.failure;
              fail(
                state.failure ??
                    ServerFailure(
                      (b) => b
                        ..code = ServerFailureCode.unknown
                        ..message = 'the server failed',
                    ),
                state.lastExitCode,
              );
          }
        },
        onDone: () {
          if (terminalSeen || done.isCompleted) {
            return;
          }
          failWith(ServerFailureCode.unknown, 'the supervisor stream ended');
        },
        onError: (Object error, StackTrace stackTrace) {
          if (terminalSeen || done.isCompleted) {
            return;
          }
          failWith(
            ServerFailureCode.unknown,
            'the supervisor stream ended',
            details: '$error',
          );
        },
      );

      var lastMetricsAt = DateTime.fromMillisecondsSinceEpoch(0);
      metricsSubscription = controller.metrics.listen((metrics) {
        if (json) {
          emit(encodeServeMetrics(metrics));
          return;
        }
        final now = DateTime.now();
        if (now.difference(lastMetricsAt) < const Duration(seconds: 5)) {
          return;
        }
        lastMetricsAt = now;
        services.err.writeln(
          'tok/s: ${metrics.tokensPerSecond.toStringAsFixed(2)}  '
          'uptime: ${metrics.uptimeSeconds ?? 0}s',
        );
      });

      logsSubscription = controller.logs.listen((entry) {
        if (json) {
          emit(encodeServeLog(entry));
          return;
        }
        switch (entry.stream) {
          case ServerLogStream.stdout:
            services.out.writeln(entry.line);
          case ServerLogStream.stderr:
          case ServerLogStream.supervisor:
            services.err.writeln(entry.line);
        }
      });

      final signals = services.interrupts;
      if (signals != null) {
        signalSubscription = signals.listen((signal) {
          final reason = signal == ProcessSignal.sigint ? 'sigint' : 'sigterm';
          // A stop request during startup aborts the wait for readiness
          // instead of letting it run into the startup timeout.
          unawaited(requestStop(reason, duringStart: !startReturned));
        });
      }

      unawaited(
        Future<void>.sync(() => controller.start(config))
            .then<void>(
              (_) {},
              onError: (Object error, StackTrace stackTrace) {
                if (done.isCompleted) {
                  return;
                }
                if (error is ServerException) {
                  terminalExit = _exitFor(error.failure.code);
                  fail(error.failure, null);
                  return;
                }
                failWith(
                  ServerFailureCode.unknown,
                  'could not start llama-server',
                  details: '$error',
                );
              },
            )
            .whenComplete(() => startReturned = true),
      );

      await done.future;
      return terminalExit;
    } finally {
      await signalSubscription?.cancel();
      await logsSubscription?.cancel();
      await metricsSubscription?.cancel();
      await statesSubscription?.cancel();
      await controller.dispose();
    }
  }

  ServerFailure _invalidConfig(List<String> violations) => ServerFailure(
    (b) => b
      ..code = ServerFailureCode.invalidConfig
      ..message = 'invalid server configuration'
      ..details = violations.join('\n'),
  );

  int _failPreStart({
    required bool json,
    required ServerFailure failure,
    required int exitCode,
  }) {
    _printFailure(failure);
    if (json) {
      writeJsonLine(services.out, encodeServeFailed(failure, null));
    }
    return exitCode;
  }

  void _printFailure(ServerFailure failure) {
    services.err.writeln('error: ${failure.code.name}: ${failure.message}');
    final details = failure.details;
    if (details != null && details.isNotEmpty) {
      services.err.writeln(details);
    }
  }

  int _exitFor(ServerFailureCode code) => switch (code) {
    ServerFailureCode.invalidConfig => ExitCodes.usage,
    ServerFailureCode.modelNotFound => ExitCodes.notFound,
    _ => ExitCodes.failure,
  };
}
