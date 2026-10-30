import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late String filePath;
  late ServerLogStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('llama_pulse_logs_');
    filePath = p.join(directory.path, 'server.log');
    store = ServerLogStore(filePath: filePath, capacity: 4, maxLineLength: 16);
  });

  tearDown(() async {
    await store.dispose();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('keeps the newest entries and numbers them monotonically', () {
    for (var index = 1; index <= 6; index++) {
      store.append(ServerLogStream.stdout, 'line $index');
    }

    final recent = store.recent;
    expect(recent.map((entry) => entry.line), [
      'line 3',
      'line 4',
      'line 5',
      'line 6',
    ]);
    expect(recent.map((entry) => entry.sequence), [3, 4, 5, 6]);
  });

  test('strips ANSI escapes and caps the line length', () {
    store.append(ServerLogStream.stderr, '\u001B[31mred\u001B[0m');
    store.append(ServerLogStream.stderr, '0123456789abcdefghij');

    expect(store.recent[0].line, 'red');
    expect(store.recent[1].line, '0123456789abcdef');
  });

  test('publishes appended entries on the broadcast stream', () async {
    final events = <ServerLogEntry>[];
    final subscription = store.entries.listen(events.add);
    addTearDown(subscription.cancel);

    store.append(ServerLogStream.supervisor, 'hello');
    await pumpEventQueue();

    expect(events, hasLength(1));
    expect(events.single.line, 'hello');
    expect(events.single.stream, ServerLogStream.supervisor);
  });

  test('writes the file and reads it back through loadExisting', () async {
    store.append(ServerLogStream.stdout, 'one');
    store.append(ServerLogStream.stderr, 'a\tb\tc');
    await store.flush();

    final reloaded = ServerLogStore(filePath: filePath, capacity: 10);
    addTearDown(reloaded.dispose);
    await reloaded.loadExisting();

    final entries = await reloaded.tail(2);
    expect(entries.map((entry) => entry.line), ['one', 'a\tb\tc']);
    expect(entries.map((entry) => entry.stream), [
      ServerLogStream.stdout,
      ServerLogStream.stderr,
    ]);
    expect(entries.map((entry) => entry.sequence), [1, 2]);
    expect(entries.first.timestampEpochMs, greaterThan(0));
  });

  test('stores the sequence on disk and returns it from tail', () async {
    store.append(ServerLogStream.stdout, 'one');
    store.append(ServerLogStream.stderr, 'two');
    await store.flush();

    final lines = await File(filePath).readAsLines();
    expect(lines, hasLength(2));
    expect(lines.first.split('\t'), hasLength(4));

    final entries = await store.tail(2);
    expect(entries.map((entry) => entry.sequence), [1, 2]);
    expect(entries.map((entry) => entry.line), ['one', 'two']);
  });

  test('reads the legacy three-field format with sequence zero', () async {
    await File(filePath)
        .writeAsString('100\tstdout\talpha\n200\tstderr\tbeta\n');

    final entries = await store.tail(2);

    expect(entries.map((entry) => entry.line), ['alpha', 'beta']);
    expect(entries.map((entry) => entry.sequence), [0, 0]);
    expect(entries.map((entry) => entry.timestampEpochMs), [100, 200]);
  });

  test('skips unparsable lines and caps loadExisting', () async {
    await File(filePath).writeAsString(
      'garbage\n'
      '1\tstdout\talpha\n'
      '2\tunknown\tbeta\n'
      '3\tstderr\tgamma\n',
    );

    await store.loadExisting(max: 2);

    expect(store.recent.map((entry) => entry.line), ['alpha', 'gamma']);
    expect(store.recent.map((entry) => entry.sequence), [1, 2]);
  });

  test('rotates to a single backup at the size limit', () async {
    final rotationStore = ServerLogStore(filePath: filePath, capacity: 10);
    addTearDown(rotationStore.dispose);
    final line = 'x' * 1000;
    for (var index = 0; index < 1200; index++) {
      rotationStore.append(ServerLogStream.stdout, line);
    }
    await rotationStore.flush();

    final backup = File('$filePath.1');
    expect(await backup.exists(), isTrue);
    expect(
      await File(filePath).length(),
      lessThanOrEqualTo(ServerLogStore.rotationBytes),
    );
    expect(
      await backup.length(),
      lessThanOrEqualTo(ServerLogStore.rotationBytes),
    );

    final all = await rotationStore.tail(2000);
    expect(all, hasLength(1200));
    expect(all.first.sequence, 1);
    expect(all.last.sequence, 1200);

    final withoutBackup = await rotationStore.tail(5, includeBackup: false);
    expect(withoutBackup, hasLength(5));
  });

  test('clear removes memory and both files', () async {
    store.append(ServerLogStream.stdout, 'one');
    await store.flush();

    await store.clear();

    expect(store.recent, isEmpty);
    expect(await File(filePath).exists(), isFalse);
    expect(await File('$filePath.1').exists(), isFalse);
    expect(await store.tail(10), isEmpty);
  });

  test('append after loadExisting continues the sequence', () async {
    await File(filePath).writeAsString('1\tstdout\talpha\n');
    await store.loadExisting();

    store.append(ServerLogStream.stdout, 'beta');

    expect(store.recent.map((entry) => entry.sequence), [1, 2]);
    expect(store.recent.last.line, 'beta');
  });
}
