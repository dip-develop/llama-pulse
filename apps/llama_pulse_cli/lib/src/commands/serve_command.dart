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
    if (parsed.errors.isNotEmpty) {
      for (final message in parsed.errors) {
        services.err.writeln('error: $message');
      }
      return ExitCodes.usage;
    }

    final stored = await services.serverConfigRepository.load();
    final config = parsed.overrides.applyTo(stored);
    final violations = const ServerConfigValidator().validateForStart(config);
    if (violations.isNotEmpty) {
      for (final violation in violations) {
        services.err.writeln('error: $violation');
      }
      return ExitCodes.usage;
    }

    final model = File(config.modelPath);
    final modelIsFile =
        await model.exists() &&
        (await model.stat()).type == FileSystemEntityType.file;
    if (!modelIsFile) {
      services.err.writeln('error: model file not found: ${config.modelPath}');
      return ExitCodes.notFound;
    }

    final json = parsed.json;
    final controller = services.createServerController();
    StreamSubscription<ServerState>? statesSubscription;
    StreamSubscription<ServerMetrics>? metricsSubscription;
    StreamSubscription<ServerLogEntry>? logsSubscription;
    StreamSubscription<ProcessSignal>? signalSubscription;
    try {
      if (await ServerStatusReader(
        stateRepository: services.serverStateRepository,
        configRepository: services.serverConfigRepository,
        controller: controller,
      ).recordedServerAnswers()) {
        services.err.writeln(
          'error: a server is already recorded; run llamapulse stop',
        );
        return ExitCodes.failure;
      }

      final ServerBinaryInfo binary;
      try {
        binary = await controller.locateBinary(config);
      } on ServerException catch (error) {
        _printFailure(error.failure);
        return _exitFor(error.failure.code);
      }

      final started = Stopwatch()..start();
      final done = Completer<void>();
      var startingEmitted = false;
      var readyEmitted = false;
      var stoppingEmitted = false;
      var failedEmitted = false;
      var stopRequested = false;
      var startReturned = false;
      var terminalExit = ExitCodes.ok;
      String? pendingStopReason;

      void emit(Map<String, Object?> event) =>
          writeJsonLine(services.out, event);

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
        if (failedEmitted) {
          return;
        }
        failedEmitted = true;
        if (json) {
          emit(encodeServeFailed(failure, lastExitCode));
        }
        _printFailure(failure);
        if (!done.isCompleted) {
          done.complete();
        }
      }

      Future<void> requestStop(String reason) async {
        if (stopRequested) {
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
          fail(error.failure, null);
        } catch (error) {
          fail(
            ServerFailure(
              (b) => b
                ..code = ServerFailureCode.unknown
                ..message = 'could not stop llama-server'
                ..details = '$error',
            ),
            null,
          );
        }
      }

      statesSubscription = controller.states.listen((state) {
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
            if (json) {
              emit(encodeServeStopped(state.lastExitCode ?? 0));
            }
            if (!done.isCompleted) {
              done.complete();
            }
          case ServerPhase.failed:
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
      });

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
          if (!startReturned) {
            pendingStopReason = reason;
            return;
          }
          unawaited(requestStop(reason));
        });
      }

      try {
        await controller.start(config);
      } on ServerException catch (error) {
        terminalExit = _exitFor(error.failure.code);
        fail(error.failure, null);
      } catch (error) {
        terminalExit = ExitCodes.failure;
        fail(
          ServerFailure(
            (b) => b
              ..code = ServerFailureCode.unknown
              ..message = 'could not start llama-server'
              ..details = '$error',
          ),
          null,
        );
      } finally {
        startReturned = true;
      }

      final pending = pendingStopReason;
      if (pending != null && !done.isCompleted) {
        unawaited(requestStop(pending));
      }

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
