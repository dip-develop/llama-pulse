// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_file_info.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<ModelFileInfo> _$modelFileInfoSerializer =
    _$ModelFileInfoSerializer();

class _$ModelFileInfoSerializer implements StructuredSerializer<ModelFileInfo> {
  @override
  final Iterable<Type> types = const [ModelFileInfo, _$ModelFileInfo];
  @override
  final String wireName = 'ModelFileInfo';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    ModelFileInfo object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'path',
      serializers.serialize(object.path, specifiedType: const FullType(String)),
      'fileName',
      serializers.serialize(
        object.fileName,
        specifiedType: const FullType(String),
      ),
      'sizeBytes',
      serializers.serialize(
        object.sizeBytes,
        specifiedType: const FullType(int),
      ),
      'modifiedAtEpochMs',
      serializers.serialize(
        object.modifiedAtEpochMs,
        specifiedType: const FullType(int),
      ),
    ];

    return result;
  }

  @override
  ModelFileInfo deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ModelFileInfoBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'path':
          result.path =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'fileName':
          result.fileName =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'sizeBytes':
          result.sizeBytes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'modifiedAtEpochMs':
          result.modifiedAtEpochMs =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
      }
    }

    return result.build();
  }
}

class _$ModelFileInfo extends ModelFileInfo {
  @override
  final String path;
  @override
  final String fileName;
  @override
  final int sizeBytes;
  @override
  final int modifiedAtEpochMs;

  factory _$ModelFileInfo([void Function(ModelFileInfoBuilder)? updates]) =>
      (ModelFileInfoBuilder()..update(updates))._build();

  _$ModelFileInfo._({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.modifiedAtEpochMs,
  }) : super._();
  @override
  ModelFileInfo rebuild(void Function(ModelFileInfoBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ModelFileInfoBuilder toBuilder() => ModelFileInfoBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ModelFileInfo &&
        path == other.path &&
        fileName == other.fileName &&
        sizeBytes == other.sizeBytes &&
        modifiedAtEpochMs == other.modifiedAtEpochMs;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, path.hashCode);
    _$hash = $jc(_$hash, fileName.hashCode);
    _$hash = $jc(_$hash, sizeBytes.hashCode);
    _$hash = $jc(_$hash, modifiedAtEpochMs.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ModelFileInfo')
          ..add('path', path)
          ..add('fileName', fileName)
          ..add('sizeBytes', sizeBytes)
          ..add('modifiedAtEpochMs', modifiedAtEpochMs))
        .toString();
  }
}

class ModelFileInfoBuilder
    implements Builder<ModelFileInfo, ModelFileInfoBuilder> {
  _$ModelFileInfo? _$v;

  String? _path;
  String? get path => _$this._path;
  set path(String? path) => _$this._path = path;

  String? _fileName;
  String? get fileName => _$this._fileName;
  set fileName(String? fileName) => _$this._fileName = fileName;

  int? _sizeBytes;
  int? get sizeBytes => _$this._sizeBytes;
  set sizeBytes(int? sizeBytes) => _$this._sizeBytes = sizeBytes;

  int? _modifiedAtEpochMs;
  int? get modifiedAtEpochMs => _$this._modifiedAtEpochMs;
  set modifiedAtEpochMs(int? modifiedAtEpochMs) =>
      _$this._modifiedAtEpochMs = modifiedAtEpochMs;

  ModelFileInfoBuilder();

  ModelFileInfoBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _path = $v.path;
      _fileName = $v.fileName;
      _sizeBytes = $v.sizeBytes;
      _modifiedAtEpochMs = $v.modifiedAtEpochMs;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ModelFileInfo other) {
    _$v = other as _$ModelFileInfo;
  }

  @override
  void update(void Function(ModelFileInfoBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ModelFileInfo build() => _build();

  _$ModelFileInfo _build() {
    final _$result =
        _$v ??
        _$ModelFileInfo._(
          path: BuiltValueNullFieldError.checkNotNull(
            path,
            r'ModelFileInfo',
            'path',
          ),
          fileName: BuiltValueNullFieldError.checkNotNull(
            fileName,
            r'ModelFileInfo',
            'fileName',
          ),
          sizeBytes: BuiltValueNullFieldError.checkNotNull(
            sizeBytes,
            r'ModelFileInfo',
            'sizeBytes',
          ),
          modifiedAtEpochMs: BuiltValueNullFieldError.checkNotNull(
            modifiedAtEpochMs,
            r'ModelFileInfo',
            'modifiedAtEpochMs',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
