import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'server_flash_attention.dart';

part 'server_config.g.dart';

/// Launch configuration for the supervised `llama-server` process.
abstract class ServerConfig
    implements Built<ServerConfig, ServerConfigBuilder> {
  /// Version of the YAML document schema that stores this configuration.
  static const int schemaVersion = 1;

  /// Path to the GGUF model file served by `llama-server`.
  String get modelPath;

  /// Address `llama-server` binds to.
  String get host;

  /// TCP port `llama-server` listens on.
  int get port;

  /// Context window size in tokens (`-c`).
  int get contextSize;

  /// Worker threads used for generation (`-t`).
  int get threads;

  /// Layers offloaded to the GPU (`-ngl`).
  int get gpuLayers;

  /// Number of parallel request slots (`-np`).
  int get parallelSlots;

  /// Model name clients pass in requests (`-a`).
  String get modelAlias;

  /// Bearer token required from clients; empty disables authentication.
  String get apiKey;

  /// Flash-attention mode (`-fa`).
  ServerFlashAttention get flashAttention;

  /// Whether the model is locked in RAM (`--mlock`).
  bool get mlock;

  /// Whether the model is memory-mapped (`--mmap`).
  bool get mmap;

  /// Raw extra `llama-server` arguments appended after the managed ones.
  BuiltList<String> get extraArgs;

  /// Path to the `llama-server` executable; empty means auto-detect.
  String get binaryPath;

  /// How long to wait for the server to answer before failing the start.
  int get startupTimeoutSeconds;

  /// Host a local client can connect to.
  ///
  /// A wildcard bind address (`0.0.0.0`, `::`, `[::]`) is not routable, so it
  /// maps to `127.0.0.1`; every other host is returned unchanged.
  String get clientHost => resolveClientHost(host);

  /// OpenAI-compatible endpoint root, for example `http://127.0.0.1:8080/v1`.
  String get baseUrl => 'http://$clientHost:$port/v1';

  /// Whether [host] is reachable from other machines.
  ///
  /// `0.0.0.0`, `::` and any non-loopback address count as exposed.
  bool get exposedOnNonLoopback => !_isLoopbackHost(host);

  factory ServerConfig([void Function(ServerConfigBuilder)? updates]) =
      _$ServerConfig;

  /// Returns the configuration used when no user configuration exists yet.
  factory ServerConfig.defaults() => ServerConfig(
    (b) => b
      ..modelPath = ''
      ..host = '127.0.0.1'
      ..port = 8080
      ..contextSize = 4096
      ..threads = 4
      ..gpuLayers = 0
      ..parallelSlots = 1
      ..modelAlias = 'llama-pulse'
      ..apiKey = ''
      ..flashAttention = ServerFlashAttention.auto
      ..mlock = false
      ..mmap = true
      ..binaryPath = ''
      ..startupTimeoutSeconds = 120,
  );

  ServerConfig._();

  static Serializer<ServerConfig> get serializer => _$serverConfigSerializer;

  /// Maps a bind address to the address a local client can connect to.
  static String resolveClientHost(String host) => switch (host) {
    '0.0.0.0' || '::' || '[::]' => '127.0.0.1',
    _ => host,
  };

  static bool _isLoopbackHost(String host) => switch (host) {
    '127.0.0.1' || 'localhost' || '::1' || '[::1]' => true,
    _ => false,
  };

  /// Returns a copy with the given fields replaced.
  ServerConfig copyWith({
    String? modelPath,
    String? host,
    int? port,
    int? contextSize,
    int? threads,
    int? gpuLayers,
    int? parallelSlots,
    String? modelAlias,
    String? apiKey,
    ServerFlashAttention? flashAttention,
    bool? mlock,
    bool? mmap,
    BuiltList<String>? extraArgs,
    String? binaryPath,
    int? startupTimeoutSeconds,
  }) => rebuild(
    (b) => b
      ..modelPath = modelPath ?? this.modelPath
      ..host = host ?? this.host
      ..port = port ?? this.port
      ..contextSize = contextSize ?? this.contextSize
      ..threads = threads ?? this.threads
      ..gpuLayers = gpuLayers ?? this.gpuLayers
      ..parallelSlots = parallelSlots ?? this.parallelSlots
      ..modelAlias = modelAlias ?? this.modelAlias
      ..apiKey = apiKey ?? this.apiKey
      ..flashAttention = flashAttention ?? this.flashAttention
      ..mlock = mlock ?? this.mlock
      ..mmap = mmap ?? this.mmap
      ..extraArgs.replace(extraArgs ?? this.extraArgs)
      ..binaryPath = binaryPath ?? this.binaryPath
      ..startupTimeoutSeconds =
          startupTimeoutSeconds ?? this.startupTimeoutSeconds,
  );
}
