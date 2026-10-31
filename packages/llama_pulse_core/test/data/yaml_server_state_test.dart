import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<Directory> createTempDirectory() async {
  final directory = await Directory.systemTemp.createTemp('llama_pulse_state_');
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return directory;
}

ServerState _state() => ServerState(
  (b) => b
    ..phase = ServerPhase.running
    ..health = ServerHealth.ok
    ..supervisorPid = 100
    ..serverPid = 101
    ..host = '0.0.0.0'
    ..port = 9090
    ..modelPath = '/models/llama-3.2-3b.Q4_K_M.gguf'
    ..binaryPath = '/opt/llama.cpp/llama-server'
    ..binaryVersion = 'b4000'
    ..startedAtEpochMs = 1000
    ..updatedAtEpochMs = 2000
    ..lastExitCode = 0
    ..failure.replace(
      ServerFailure(
        (b) => b
          ..code = ServerFailureCode.portInUse
          ..message = 'port 9090 is in use'
          ..details = 'bind failed',
      ),
    ),
);

void main() {
  late Directory directory;
  late YamlServerStateRepository repository;
  late File stateFile;

  setUp(() async {
    directory = await createTempDirectory();
    repository = YamlServerStateRepository(
      store: YamlFileConfigStore(directory: directory.path),
      serializers: serializers,
    );
    stateFile = File(p.join(directory.path, 'server-state.yaml'));
  });

  test('toDocument starts with the schema version and a state mapping', () {
    final document = repository.toDocument(
      ServerState.stopped(updatedAtEpochMs: 5),
    );

    expect(document.keys.toList(), ['schemaVersion', 'state']);
    expect(document['schemaVersion'], 1);

    final lines = YamlEncoder.encode(document).split('\n');
    expect(lines.first, 'schemaVersion: 1');
    expect(lines[1], 'state:');
    expect(lines[2], '  phase: stopped');
  });

  test('round-trips a running state with a failure', () async {
    await repository.save(_state());

    expect(await repository.load(), _state());
  });

  test('round-trips a stopped state', () async {
    final state = ServerState.stopped(updatedAtEpochMs: 7);

    await repository.save(state);

    expect(await repository.load(), state);
  });

  test('save writes the same document toDocument returns', () async {
    await repository.save(_state());

    expect(
      await stateFile.readAsString(),
      YamlEncoder.encode(repository.toDocument(_state())),
    );
  });

  test('load returns null for a missing document', () async {
    expect(await repository.load(), isNull);
  });

  test('load returns null for garbage YAML', () async {
    await stateFile.writeAsString('not: [valid');

    expect(await repository.load(), isNull);
  });

  test('load returns null for an unknown schema version', () async {
    await stateFile.writeAsString(
      YamlEncoder.encode(<String, Object?>{
        'schemaVersion': 99,
        'state': repository.toDocument(_state())['state'],
      }),
    );

    expect(await repository.load(), isNull);
  });

  test('load returns null when state is not a map', () async {
    await stateFile.writeAsString('schemaVersion: 1\nstate: 5\n');

    expect(await repository.load(), isNull);
  });

  test('load returns null when a field is missing', () async {
    await stateFile.writeAsString(
      YamlEncoder.encode(<String, Object?>{
        'schemaVersion': 1,
        'state': <String, Object?>{'phase': 'running'},
      }),
    );

    expect(await repository.load(), isNull);
  });

  test('load ignores unknown extra fields', () async {
    final state = repository.toDocument(_state())['state']!;
    await stateFile.writeAsString(
      YamlEncoder.encode(<String, Object?>{
        'schemaVersion': 1,
        'state': <String, Object?>{
          ...state as Map<String, Object?>,
          'futureField': 'ignored',
        },
      }),
    );

    expect(await repository.load(), _state());
  });

  test('clear removes the document', () async {
    await repository.save(_state());

    await repository.clear();

    expect(await stateFile.exists(), isFalse);
    expect(await repository.load(), isNull);
  });

  test('clear is a no-op when no document exists', () async {
    await repository.clear();

    expect(await stateFile.exists(), isFalse);
  });
}
