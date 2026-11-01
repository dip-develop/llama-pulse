import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/runtime_fakes.dart';

const _cudaDriver = 'version: 0.8.0-dev (build 11960, commit 8642541)';

void main() {
  late Directory temp;
  late List<int> archive;
  late RuntimeAsset cpuAsset;
  late RuntimeAsset cudaAsset;
  late RuntimeAsset cudartAsset;
  late RuntimeRelease release;
  late FakeRuntimeProbe probe;
  late StringBuffer out;
  late StringBuffer err;
  late FakeCliRuntimeFetcher fetcher;
  late LlamaPulseCommandRunner runner;

  LlamaPulseCommandRunner buildRunner({Stream<List<int>>? stdin}) =>
      LlamaPulseCommandRunner(
        CliServices(
          paths: AppPaths(configDirectory: temp.path),
          configStore: InMemoryConfigStore(),
          out: out,
          err: err,
          stdin: stdin,
          runtimeProbe: probe,
          runtimeFetcherFactory: () => fetcher,
          runtimeRelease: release,
          runtimeProcessExecutor: FakeCliProcessExecutor(
            const ProcessOutput(exitCode: 0, stdout: _cudaDriver, stderr: ''),
          ),
        ),
      );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('llamapulse_runtime_');
    archive = buildRuntimeTarGz(<String, String>{
      'llama-b11960/llama-server': 'server',
      'llama-b11960/libllama.so': 'llama',
      'llama-b11960/libggml.so': 'ggml',
      'llama-b11960/libggml-cpu.so': 'cpu',
    });
    final digest = sha256.convert(archive).toString();
    cpuAsset = RuntimeAsset(
      tag: 'v0.8.0',
      backend: RuntimeBackend.cpu,
      platform: RuntimePlatform.linuxX64,
      assetName: 'llama-b11960-bin-ubuntu-x64.tar.gz',
      sha256: digest,
      sizeBytes: archive.length,
    );
    cudartAsset = RuntimeAsset(
      tag: 'v0.8.0',
      backend: RuntimeBackend.cuda13,
      platform: RuntimePlatform.linuxX64,
      assetName: 'cudart-llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz',
      sha256: digest,
      sizeBytes: archive.length,
    );
    cudaAsset = RuntimeAsset(
      tag: 'v0.8.0',
      backend: RuntimeBackend.cuda13,
      platform: RuntimePlatform.linuxX64,
      assetName: 'llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz',
      sha256: digest,
      sizeBytes: archive.length,
      cudartAsset: cudartAsset,
    );
    release = RuntimeRelease(
      tag: 'v0.8.0',
      build: 'b11960',
      commit: '8642541b255bfb5dc39cd351a178be09013a55d6',
      ggmlVersion: '0.28.0',
      assets: <RuntimeAsset>[cpuAsset, cudaAsset],
    );
    probe = FakeRuntimeProbe();
    fetcher = FakeCliRuntimeFetcher(body: archive);
    out = StringBuffer();
    err = StringBuffer();
    runner = buildRunner();
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  List<String> jsonLines() => const LineSplitter()
      .convert(out.toString())
      .where((line) => line.isNotEmpty)
      .toList();

  test('list reports no runtimes', () async {
    expect(await runner.run(['runtime', 'list']), ExitCodes.ok);

    expect(out.toString(), contains('selected: none'));
    expect(out.toString(), contains('no runtimes installed'));
  });

  test('status reports hardware, recommendation and no install', () async {
    expect(await runner.run(['runtime', 'status', '--json']), ExitCodes.ok);

    final json = jsonDecode(jsonLines().single) as Map<String, Object?>;
    expect(json['type'], 'runtimeStatus');
    expect((json['host']! as Map<String, Object?>)['platform'], 'linux-x64');
    expect(
      (json['recommendation']! as Map<String, Object?>)['backend'],
      'cuda13',
    );
    expect(json['selected'], isNull);
    expect(json['installed'], isEmpty);
    expect((json['gate']! as Map<String, Object?>)['verdict'], 'notInstalled');
    final backends = (json['backends']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(backends.map((b) => b['id']), contains('cuda13'));
    expect(
      backends.firstWhere((b) => b['id'] == 'cuda13')['downloadSizeBytes'],
      archive.length,
    );
  });

  test('status reports an unsupported host with exit 1', () async {
    probe.detection = FakeRuntimeProbe.unsupported();

    expect(await runner.run(['runtime', 'status']), ExitCodes.failure);

    expect(out.toString(), contains('unsupported'));
  });

  test('install downloads, verifies and records the runtime', () async {
    final code = await runner.run([
      'runtime',
      'install',
      '--backend',
      'cpu',
      '--json',
    ]);

    expect(code, ExitCodes.ok);
    final lines = jsonLines();
    expect(lines.first, contains('"type":"runtimeProgress"'));
    final installed = jsonDecode(lines.last) as Map<String, Object?>;
    expect(installed['type'], 'runtimeInstall');
    expect(installed['backend'], 'cpu');
    expect(installed['llamaVersion'], '0.8.0-dev');
    final directory = p.join(temp.path, 'runtime', 'v0.8.0', 'cpu');
    expect(installed['directory'], directory);
    expect(File(p.join(directory, 'llama-server')).existsSync(), isTrue);

    final store = YamlRuntimeStore(paths: AppPaths(configDirectory: temp.path));
    final manifest = await store.manifest('v0.8.0', RuntimeBackend.cpu);
    expect(manifest, isNotNull);
    expect(manifest!.buildId, 'b11960');
    expect(manifest.commit, '8642541');
    expect(manifest.llamaVersion, '0.8.0-dev');
    expect(manifest.backendLibs.toList(), <String>['libggml-cpu.so']);
  });

  test('install prints the installed directory in human mode', () async {
    expect(
      await runner.run(['runtime', 'install', '--backend', 'cpu']),
      ExitCodes.ok,
    );

    expect(
      out.toString(),
      contains('installed v0.8.0/cpu at ${p.join(temp.path, 'runtime')}'),
    );
    expect(err.toString(), contains('installing cpu for linux-x64'));
  });

  test('install rejects an unknown backend', () async {
    expect(
      await runner.run(['runtime', 'install', '--backend', 'tpu']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('unknown backend "tpu"'));
    expect(fetcher.requests, isEmpty);
  });

  test('install rejects an unknown tag', () async {
    expect(
      await runner.run([
        'runtime',
        'install',
        '--backend',
        'cpu',
        '--tag',
        'v0.9.0',
      ]),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('unknown release "v0.9.0"'));
  });

  test('install requires a supported host', () async {
    probe.detection = FakeRuntimeProbe.unsupported();

    expect(
      await runner.run(['runtime', 'install', '--backend', 'cpu']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('no build for linux/arm64'));
  });

  test('a CUDA install needs consent', () async {
    expect(
      await runner.run(['runtime', 'install', '--backend', 'cuda13']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('pass --yes'));
    expect(fetcher.requests, isEmpty);
  });

  test('a CUDA install downloads the runtime archive after consent', () async {
    expect(
      await runner.run(['runtime', 'install', '--backend', 'cuda13', '--yes']),
      ExitCodes.ok,
    );

    expect(fetcher.requests, hasLength(2));
    expect(
      fetcher.requests.map((uri) => uri.pathSegments.last),
      containsAll(<String>[cudaAsset.assetName, cudartAsset.assetName]),
    );
  });

  test('a declined prompt installs nothing', () async {
    final stdin = Stream<List<int>>.value(utf8.encode('no\n'));

    expect(
      await buildRunner(stdin: stdin)
          .run(['runtime', 'install', '--backend', 'cuda13']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('installation declined'));
    expect(fetcher.requests, isEmpty);
  });

  test('an accepted prompt installs the CUDA backend', () async {
    final stdin = Stream<List<int>>.value(utf8.encode('y\n'));

    expect(
      await buildRunner(stdin: stdin)
          .run(['runtime', 'install', '--backend', 'cuda13']),
      ExitCodes.ok,
    );

    expect(fetcher.requests, hasLength(2));
  });

  test('a second install without --force exits 2', () async {
    await runner.run(['runtime', 'install', '--backend', 'cpu']);
    fetcher.requests.clear();

    expect(
      await runner.run(['runtime', 'install', '--backend', 'cpu']),
      ExitCodes.usage,
    );

    expect(err.toString(), contains('already installed'));
    expect(fetcher.requests, isEmpty);

    expect(
      await runner.run(['runtime', 'install', '--backend', 'cpu', '--force']),
      ExitCodes.ok,
    );
  });

  test('a checksum mismatch exits 4', () async {
    final tampered = RuntimeRelease(
      tag: 'v0.8.0',
      build: 'b11960',
      commit: release.commit,
      ggmlVersion: '0.28.0',
      assets: <RuntimeAsset>[
        RuntimeAsset(
          tag: 'v0.8.0',
          backend: RuntimeBackend.cpu,
          platform: RuntimePlatform.linuxX64,
          assetName: cpuAsset.assetName,
          sha256: 'f' * 64,
          sizeBytes: archive.length,
        ),
      ],
    );
    release = tampered;
    runner = buildRunner();

    expect(
      await runner.run(['runtime', 'install', '--backend', 'cpu']),
      ExitCodes.integrity,
    );

    expect(err.toString(), contains('SHA-256'));
  });

  test('an unreadable payload exits 4', () async {
    final garbage = utf8.encode('this is not a tar.gz');
    final broken = RuntimeRelease(
      tag: 'v0.8.0',
      build: 'b11960',
      commit: release.commit,
      ggmlVersion: '0.28.0',
      assets: <RuntimeAsset>[
        RuntimeAsset(
          tag: 'v0.8.0',
          backend: RuntimeBackend.cpu,
          platform: RuntimePlatform.linuxX64,
          assetName: cpuAsset.assetName,
          sha256: sha256.convert(garbage).toString(),
          sizeBytes: garbage.length,
        ),
      ],
    );
    release = broken;
    fetcher = FakeCliRuntimeFetcher(body: garbage);
    runner = buildRunner();

    expect(
      await runner.run(['runtime', 'install', '--backend', 'cpu']),
      ExitCodes.integrity,
    );
  });

  test('a network failure exits 5', () async {
    fetcher = FakeCliRuntimeFetcher(
      body: archive,
      openError: const RuntimeException(
        RuntimeFailureCode.network,
        'connection refused',
      ),
    );
    runner = buildRunner();

    expect(
      await runner.run(['runtime', 'install', '--backend', 'cpu']),
      ExitCodes.network,
    );

    expect(err.toString(), contains('connection refused'));
  });

  test('an interrupted download exits 130', () async {
    fetcher = FakeCliRuntimeFetcher(
      body: archive,
      chunkSize: 8,
      onChunk: (int sent, RuntimeCancelToken? cancel) => cancel?.cancel(),
    );
    runner = buildRunner();

    expect(
      await runner.run(['runtime', 'install', '--backend', 'cpu']),
      ExitCodes.interrupted,
    );

    expect(err.toString(), contains('interrupted'));
  });

  test('select marks an installed runtime and remove deletes it', () async {
    await runner.run(['runtime', 'install', '--backend', 'cpu']);

    expect(
      await runner.run(['runtime', 'select', 'v0.8.0', 'cpu']),
      ExitCodes.ok,
    );
    out.clear();
    expect(await runner.run(['runtime', 'list', '--json']), ExitCodes.ok);
    final listed = jsonDecode(jsonLines().single) as Map<String, Object?>;
    expect((listed['selected']! as Map<String, Object?>)['id'], 'v0.8.0/cpu');

    expect(
      await runner.run(['runtime', 'remove', 'v0.8.0', 'cpu']),
      ExitCodes.ok,
    );
    expect(
      Directory(p.join(temp.path, 'runtime', 'v0.8.0', 'cpu')).existsSync(),
      isFalse,
    );
    out.clear();
    expect(await runner.run(['runtime', 'list']), ExitCodes.ok);
    expect(out.toString(), contains('no runtimes installed'));
  });

  test('select and remove report a missing runtime with exit 3', () async {
    expect(
      await runner.run(['runtime', 'select', 'v0.8.0', 'cpu']),
      ExitCodes.notFound,
    );
    expect(
      await runner.run(['runtime', 'remove', 'v0.8.0', 'cpu']),
      ExitCodes.notFound,
    );
    expect(err.toString(), contains('is not installed'));
  });

  test('select rejects a malformed target with exit 2', () async {
    expect(await runner.run(['runtime', 'select', 'v0.8.0']), ExitCodes.usage);
    expect(
      await runner.run(['runtime', 'select', 'v0.8.0', 'tpu']),
      ExitCodes.usage,
    );
  });

  test('status recognises the installed runtime and its gate', () async {
    await runner.run(['runtime', 'install', '--backend', 'cpu']);
    await runner.run(['runtime', 'select', 'v0.8.0', 'cpu']);
    out.clear();

    expect(await runner.run(['runtime', 'status', '--json']), ExitCodes.ok);

    final json = jsonDecode(jsonLines().single) as Map<String, Object?>;
    final gate = json['gate']! as Map<String, Object?>;
    expect(gate['verdict'], 'attested');
    expect(gate['accepted'], isTrue);
    expect((json['selected']! as Map<String, Object?>)['id'], 'v0.8.0/cpu');
  });
}
