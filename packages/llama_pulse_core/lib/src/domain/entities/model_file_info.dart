import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'model_file_info.g.dart';

/// Metadata for a model file discovered on disk.
abstract class ModelFileInfo
    implements Built<ModelFileInfo, ModelFileInfoBuilder> {
  /// Absolute path to the model file.
  String get path;

  /// File name including extension.
  String get fileName;

  /// File size in bytes.
  int get sizeBytes;

  /// Last modification time as milliseconds since the Unix epoch.
  int get modifiedAtEpochMs;

  /// File size in mebibytes.
  double get sizeMiB => sizeBytes / 1048576;

  factory ModelFileInfo([void Function(ModelFileInfoBuilder)? updates]) =
      _$ModelFileInfo;

  ModelFileInfo._();

  static Serializer<ModelFileInfo> get serializer => _$modelFileInfoSerializer;
}
