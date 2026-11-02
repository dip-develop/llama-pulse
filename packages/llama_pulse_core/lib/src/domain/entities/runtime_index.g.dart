// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runtime_index.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<RuntimeIndex> _$runtimeIndexSerializer = _$RuntimeIndexSerializer();

class _$RuntimeIndexSerializer implements StructuredSerializer<RuntimeIndex> {
  @override
  final Iterable<Type> types = const [RuntimeIndex, _$RuntimeIndex];
  @override
  final String wireName = 'RuntimeIndex';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    RuntimeIndex object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'selectedTag',
      serializers.serialize(
        object.selectedTag,
        specifiedType: const FullType(String),
      ),
      'installed',
      serializers.serialize(
        object.installed,
        specifiedType: const FullType(BuiltList, const [
          const FullType(RuntimeInstallRef),
        ]),
      ),
    ];
    Object? value;
    value = object.selectedBackend;
    if (value != null) {
      result
        ..add('selectedBackend')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(RuntimeBackend),
          ),
        );
    }
    return result;
  }

  @override
  RuntimeIndex deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RuntimeIndexBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'selectedTag':
          result.selectedTag =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'selectedBackend':
          result.selectedBackend = serializers.deserialize(
            value,
            specifiedType: const FullType(RuntimeBackend),
          ) as RuntimeBackend?;
          break;
        case 'installed':
          result.installed.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(RuntimeInstallRef),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
      }
    }

    return result.build();
  }
}

class _$RuntimeIndex extends RuntimeIndex {
  @override
  final String selectedTag;
  @override
  final RuntimeBackend? selectedBackend;
  @override
  final BuiltList<RuntimeInstallRef> installed;

  factory _$RuntimeIndex([void Function(RuntimeIndexBuilder)? updates]) =>
      (RuntimeIndexBuilder()..update(updates))._build();

  _$RuntimeIndex._({
    required this.selectedTag,
    this.selectedBackend,
    required this.installed,
  }) : super._();
  @override
  RuntimeIndex rebuild(void Function(RuntimeIndexBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RuntimeIndexBuilder toBuilder() => RuntimeIndexBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RuntimeIndex &&
        selectedTag == other.selectedTag &&
        selectedBackend == other.selectedBackend &&
        installed == other.installed;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, selectedTag.hashCode);
    _$hash = $jc(_$hash, selectedBackend.hashCode);
    _$hash = $jc(_$hash, installed.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RuntimeIndex')
          ..add('selectedTag', selectedTag)
          ..add('selectedBackend', selectedBackend)
          ..add('installed', installed))
        .toString();
  }
}

class RuntimeIndexBuilder
    implements Builder<RuntimeIndex, RuntimeIndexBuilder> {
  _$RuntimeIndex? _$v;

  String? _selectedTag;
  String? get selectedTag => _$this._selectedTag;
  set selectedTag(String? selectedTag) => _$this._selectedTag = selectedTag;

  RuntimeBackend? _selectedBackend;
  RuntimeBackend? get selectedBackend => _$this._selectedBackend;
  set selectedBackend(RuntimeBackend? selectedBackend) =>
      _$this._selectedBackend = selectedBackend;

  ListBuilder<RuntimeInstallRef>? _installed;
  ListBuilder<RuntimeInstallRef> get installed =>
      _$this._installed ??= ListBuilder<RuntimeInstallRef>();
  set installed(ListBuilder<RuntimeInstallRef>? installed) =>
      _$this._installed = installed;

  RuntimeIndexBuilder();

  RuntimeIndexBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _selectedTag = $v.selectedTag;
      _selectedBackend = $v.selectedBackend;
      _installed = $v.installed.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RuntimeIndex other) {
    _$v = other as _$RuntimeIndex;
  }

  @override
  void update(void Function(RuntimeIndexBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RuntimeIndex build() => _build();

  _$RuntimeIndex _build() {
    _$RuntimeIndex _$result;
    try {
      _$result =
          _$v ??
          _$RuntimeIndex._(
            selectedTag: BuiltValueNullFieldError.checkNotNull(
              selectedTag,
              r'RuntimeIndex',
              'selectedTag',
            ),
            selectedBackend: selectedBackend,
            installed: installed.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'installed';
        installed.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'RuntimeIndex',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
