import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'server_failure_code.dart';

part 'server_failure.g.dart';

/// Structured description of a failed server operation.
///
/// Deliberately not an exception: it is data held in the server state. Thrown
/// errors carry it inside a `ServerException`.
abstract class ServerFailure
    implements Built<ServerFailure, ServerFailureBuilder> {
  /// Classified reason for the failure.
  ServerFailureCode get code;

  /// Human-readable message suitable for the UI.
  String get message;

  /// Optional supervisor output with technical detail.
  String? get details;

  factory ServerFailure([void Function(ServerFailureBuilder)? updates]) =
      _$ServerFailure;

  ServerFailure._();

  static Serializer<ServerFailure> get serializer => _$serverFailureSerializer;
}
