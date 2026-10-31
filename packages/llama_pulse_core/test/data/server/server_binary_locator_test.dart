import 'dart:io';

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
    await Process.run('chmod', ['755', path]);
    return file;
  }

  Future<File> createPlainFile(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('not executable');
    await Process.run('chmod', ['644', path]);
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
