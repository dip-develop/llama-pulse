import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _version = '0.8.0';

Future<ServerBinaryInfo> _fakeReader(String path) async => ServerBinaryInfo(
  (b) => b
    ..path = path
    ..version = _version
    ..supported = true
    ..rawOutput = 'version: $_version',
);

/// One installed runtime per backend, newest first in [installedAt].
RuntimeIndex _index({
  RuntimeBackend? selected,
  Map<RuntimeBackend, int> installedAt = const <RuntimeBackend, int>{
    RuntimeBackend.cpu: 10,
    RuntimeBackend.cuda13: 20,
  },
}) => RuntimeIndex(
  (b) => b
    ..selectedTag = selected == null ? '' : 'v0.8.0'
    ..selectedBackend = selected
    ..installed = BuiltList<RuntimeInstallRef>(<RuntimeInstallRef>[
      for (final entry in installedAt.entries)
        RuntimeInstallRef(
          (r) => r
            ..tag = 'v0.8.0'
            ..backend = entry.key
            ..platform = RuntimePlatform.linuxX64
            ..installedAtEpochMs = entry.value
            ..sizeBytes = 1,
        ),
    ]).toBuilder(),
);

final class _FakeRuntimeStore implements RuntimeStore {
  RuntimeIndex current = RuntimeIndex.empty();

  @override
  Future<RuntimeIndex> index() async => current;

  @override
  Future<List<RuntimeInstallRef>> list() async => current.installed.toList();

  @override
  Future<RuntimeManifest?> manifest(String tag, RuntimeBackend backend) async =>
      null;

  @override
  Future<void> select(String tag, RuntimeBackend backend) async {}

  @override
  Future<void> remove(String tag, RuntimeBackend backend) async {}

  @override
  Future<void> commit(
    RuntimeBackend backend,
    RuntimeManifest manifest,
    Directory stagingDir, {
    bool force = false,
  }) async {}

  @override
  Future<void> cleanupOrphans({
    Duration olderThan = const Duration(days: 1),
  }) async {}

  @override
  String installDirectory(String tag, RuntimeBackend backend) =>
      p.join(tag, backend.id);
}

void main() {
  late Directory root;
  late Directory configDirectory;
  late Directory executableDirectory;
  late Directory pathDirectory;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('llama_pulse_locator_');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    configDirectory = Directory(p.join(root.path, 'config'));
    executableDirectory = Directory(p.join(root.path, 'app'));
    pathDirectory = Directory(p.join(root.path, 'path'));
    await configDirectory.create(recursive: true);
    await executableDirectory.create(recursive: true);
    await pathDirectory.create(recursive: true);
  });

  ServerBinaryLocatorImpl locator({
    Map<String, String> environment = const {'PATH': ''},
    String operatingSystem = 'linux',
  }) => ServerBinaryLocatorImpl(
    paths: AppPaths(configDirectory: configDirectory.path),
    executablePath: p.join(executableDirectory.path, 'llama_pulse'),
    environment: environment,
    operatingSystem: operatingSystem,
    versionReader: _fakeReader,
  );

  Future<File> createExecutable(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('#!/bin/sh\n');
    // Windows has no chmod and `_isExecutable` already treats every file as
    // executable there.
    if (!Platform.isWindows) {
      await Process.run('chmod', ['755', path]);
    }
    return file;
  }

  Future<File> createPlainFile(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('not executable');
    if (!Platform.isWindows) {
      await Process.run('chmod', ['644', path]);
    }
    return file;
  }

  Future<ServerException> capture(
    Future<ServerBinaryInfo> Function() call,
  ) async {
    try {
      await call();
    } on ServerException catch (error) {
      return error;
    }
    fail('expected a ServerException');
  }

  test(
    'explicit binaryPath wins over the environment and the bundle',
    () async {
      final explicit = await createExecutable(
        p.join(root.path, 'explicit', 'llama-server'),
      );
      await createExecutable(
        p.join(executableDirectory.path, 'data', 'llama-server'),
      );
      final fromEnvironment = await createExecutable(
        p.join(root.path, 'env', 'llama-server'),
      );

      final info = await locator(
        environment: {'PATH': '', 'LLAMA_PULSE_SERVER': fromEnvironment.path},
      ).locate(ServerConfig.defaults().copyWith(binaryPath: explicit.path));

      expect(info.path, explicit.path);
      expect(info.version, _version);
    },
  );

  test('an absolute LLAMA_PULSE_SERVER wins over the bundled binary', () async {
    await createExecutable(
      p.join(executableDirectory.path, 'data', 'llama-server'),
    );
    final fromEnvironment = await createExecutable(
      p.join(root.path, 'env', 'llama-server'),
    );

    final info = await locator(
      environment: {'PATH': '', 'LLAMA_PULSE_SERVER': fromEnvironment.path},
    ).locate(ServerConfig.defaults());

    expect(info.path, fromEnvironment.path);
  });

  test('resolves a bare LLAMA_PULSE_SERVER name on PATH', () async {
    final onPath = await createExecutable(
      p.join(pathDirectory.path, 'llama-server'),
    );

    final info = await locator(
      environment: {
        'PATH': pathDirectory.path,
        'LLAMA_PULSE_SERVER': 'llama-server',
      },
    ).locate(ServerConfig.defaults());

    expect(info.path, onPath.path);
  });

  test('resolves the bundled data directory', () async {
    final bundled = await createExecutable(
      p.join(executableDirectory.path, 'data', 'llama-server'),
    );

    final info = await locator().locate(ServerConfig.defaults());

    expect(info.path, bundled.path);
  });

  test('resolves next to the executable', () async {
    final adjacent = await createExecutable(
      p.join(executableDirectory.path, 'llama-server'),
    );

    final info = await locator().locate(ServerConfig.defaults());

    expect(info.path, adjacent.path);
  });

  test('resolves the app bin directory', () async {
    final inBin = await createExecutable(
      p.join(configDirectory.path, 'bin', 'llama-server'),
    );

    final info = await locator().locate(ServerConfig.defaults());

    expect(info.path, inBin.path);
  });

  test('scans PATH entries in order', () async {
    final empty = Directory(p.join(root.path, 'empty'));
    await empty.create();
    final onPath = await createExecutable(
      p.join(pathDirectory.path, 'llama-server'),
    );

    final info = await locator(
      environment: {'PATH': '${empty.path}:${pathDirectory.path}'},
    ).locate(ServerConfig.defaults());

    expect(info.path, onPath.path);
  });

  test('uses the .exe name on Windows', () async {
    final bundled = await createExecutable(
      p.join(executableDirectory.path, 'data', 'llama-server.exe'),
    );

    final info = await locator(operatingSystem: 'windows')
        .locate(ServerConfig.defaults());

    expect(info.path, bundled.path);
    expect(p.basename(info.path), 'llama-server.exe');
  });

  group('managed runtimes', () {
    final store = _FakeRuntimeStore();

    ServerBinaryLocatorImpl runtimeLocator() => ServerBinaryLocatorImpl(
      paths: AppPaths(configDirectory: configDirectory.path),
      executablePath: p.join(executableDirectory.path, 'llama_pulse'),
      environment: const {'PATH': ''},
      operatingSystem: 'linux',
      versionReader: _fakeReader,
      runtimeStore: store,
    );

    test('a selected runtime comes before config/bin and PATH', () async {
      final selected = await createExecutable(
        p.join(
          configDirectory.path,
          'runtime',
          'v0.8.0',
          'cuda13',
          'llama-server',
        ),
      );
      await createExecutable(
        p.join(configDirectory.path, 'bin', 'llama-server'),
      );
      store.current = _index(selected: RuntimeBackend.cuda13);

      final info = await runtimeLocator().locate(ServerConfig.defaults());

      expect(info.path, selected.path);
      expect(
        info.runtimeDirectory,
        p.join(configDirectory.path, 'runtime', 'v0.8.0', 'cuda13'),
      );
    });

    test('without a selection the newest install wins', () async {
      final older = await createExecutable(
        p.join(
          configDirectory.path,
          'runtime',
          'v0.8.0',
          'cpu',
          'llama-server',
        ),
      );
      final newer = await createExecutable(
        p.join(
          configDirectory.path,
          'runtime',
          'v0.8.0',
          'vulkan',
          'llama-server',
        ),
      );
      store.current = _index(
        installedAt: <RuntimeBackend, int>{
          RuntimeBackend.cpu: 10,
          RuntimeBackend.vulkan: 20,
        },
      );

      final info = await runtimeLocator().locate(ServerConfig.defaults());

      expect(info.path, newer.path);
      expect(info.runtimeDirectory, isNotNull);
      expect(older.existsSync(), isTrue);
    });

    test(
      'falls back to config/bin when the runtime binary is missing',
      () async {
        final configured = await createExecutable(
          p.join(configDirectory.path, 'bin', 'llama-server'),
        );
        store.current = _index(selected: RuntimeBackend.cpu);

        final info = await runtimeLocator().locate(ServerConfig.defaults());

        expect(info.path, configured.path);
        expect(info.runtimeDirectory, isNull);
      },
    );
  });

  group('bundled runtimes', () {
    final store = _FakeRuntimeStore();

    ServerBinaryLocatorImpl bundleLocator() => ServerBinaryLocatorImpl(
      paths: AppPaths(configDirectory: configDirectory.path),
      executablePath: p.join(executableDirectory.path, 'llama_pulse'),
      environment: const {'PATH': ''},
      operatingSystem: 'linux',
      versionReader: _fakeReader,
      runtimeStore: store,
    );

    test('finds a runtime shipped beside the executable', () async {
      final bundled = await createExecutable(
        p.join(
          executableDirectory.path,
          'runtime',
          'v0.8.0',
          'cpu',
          'llama-server',
        ),
      );

      final info = await bundleLocator().locate(ServerConfig.defaults());

      expect(info.path, bundled.path);
      expect(
        info.runtimeDirectory,
        p.join(executableDirectory.path, 'runtime', 'v0.8.0', 'cpu'),
      );
    });

    test('a config runtime wins over the bundled one', () async {
      final configured = await createExecutable(
        p.join(
          configDirectory.path,
          'runtime',
          'v0.8.0',
          'cuda13',
          'llama-server',
        ),
      );
      await createExecutable(
        p.join(
          executableDirectory.path,
          'runtime',
          'v0.8.0',
          'cpu',
          'llama-server',
        ),
      );
      store.current = _index(selected: RuntimeBackend.cuda13);

      final info = await bundleLocator().locate(ServerConfig.defaults());

      expect(info.path, configured.path);
      expect(
        info.runtimeDirectory,
        p.join(configDirectory.path, 'runtime', 'v0.8.0', 'cuda13'),
      );
    });

    test('a bundled runtime comes before config/bin', () async {
      final bundled = await createExecutable(
        p.join(
          executableDirectory.path,
          'runtime',
          'v0.8.0',
          'cpu',
          'llama-server',
        ),
      );
      await createExecutable(
        p.join(configDirectory.path, 'bin', 'llama-server'),
      );

      final info = await bundleLocator().locate(ServerConfig.defaults());

      expect(info.path, bundled.path);
    });
  });

  test('throws binaryNotFound and lists every searched path', () async {
    final error = await capture(
      () => locator().locate(ServerConfig.defaults()),
    );

    expect(error.failure.code, ServerFailureCode.binaryNotFound);
    expect(error.failure.message, 'llama-server not found');
    final details = error.failure.details!;
    expect(
      details,
      contains(p.join(executableDirectory.path, 'data', 'llama-server')),
    );
    expect(details, contains(p.join(executableDirectory.path, 'llama-server')));
    expect(
      details,
      contains(p.join(configDirectory.path, 'bin', 'llama-server')),
    );
  });

  test('throws binaryNotFound for a missing explicit path', () async {
    final error = await capture(
      () => locator().locate(
        ServerConfig.defaults().copyWith(
          binaryPath: p.join(root.path, 'missing', 'llama-server'),
        ),
      ),
    );

    expect(error.failure.code, ServerFailureCode.binaryNotFound);
    expect(error.failure.details, contains('missing'));
  });

  test(
    'throws binaryNotExecutable for a non-executable POSIX candidate',
    () async {
      final plain = await createPlainFile(
        p.join(configDirectory.path, 'bin', 'llama-server'),
      );

      final error = await capture(
        () => locator().locate(ServerConfig.defaults()),
      );

      expect(error.failure.code, ServerFailureCode.binaryNotExecutable);
      expect(error.failure.details, contains(plain.path));
    },
    skip: Platform.isWindows ? 'POSIX permission bits' : null,
  );

  test(
    'throws binaryNotExecutable for a non-executable explicit path',
    () async {
      final plain = await createPlainFile(
        p.join(root.path, 'explicit', 'llama-server'),
      );

      final error = await capture(
        () => locator().locate(
          ServerConfig.defaults().copyWith(binaryPath: plain.path),
        ),
      );

      expect(error.failure.code, ServerFailureCode.binaryNotExecutable);
    },
    skip: Platform.isWindows ? 'POSIX permission bits' : null,
  );
}
