import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'server_failure_code.g.dart';

/// Machine-readable reason for a server failure.
class ServerFailureCode extends EnumClass {
  /// The `llama-server` executable was not found.
  static const ServerFailureCode binaryNotFound = _$binaryNotFound;

  /// The executable exists but cannot be run.
  static const ServerFailureCode binaryNotExecutable = _$binaryNotExecutable;

  /// The executable's version is not supported.
  static const ServerFailureCode unsupportedVersion = _$unsupportedVersion;

  /// The configured port is already in use.
  static const ServerFailureCode portInUse = _$portInUse;

  /// The model file is missing or unreadable.
  static const ServerFailureCode modelNotFound = _$modelNotFound;

  /// The configuration violates a launch rule.
  static const ServerFailureCode invalidConfig = _$invalidConfig;

  /// The server did not answer within the startup timeout.
  static const ServerFailureCode startupTimeout = _$startupTimeout;

  /// The process exited unexpectedly.
  static const ServerFailureCode processExited = _$processExited;

  /// The health probe kept failing.
  static const ServerFailureCode healthCheckFailed = _$healthCheckFailed;

  /// An HTTP request to the server failed.
  static const ServerFailureCode httpError = _$httpError;

  /// The stored state document could not be read.
  static const ServerFailureCode stateUnreadable = _$stateUnreadable;

  /// The failure could not be classified.
  static const ServerFailureCode unknown = _$unknown;

  const ServerFailureCode._(super.name);

  /// All codes, in declaration order.
  static BuiltSet<ServerFailureCode> get values => _$values;

  /// Looks up a code by its wire name.
  static ServerFailureCode valueOf(String name) => _$valueOf(name);

  static Serializer<ServerFailureCode> get serializer =>
      _$serverFailureCodeSerializer;
}
