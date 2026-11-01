import '../entities/parameter_spec.dart';

/// Canonical string form, validation and default handling for one catalog
/// parameter value.
abstract final class ParameterValueCodec {
  /// Maximum length of a stored value, in characters.
  static const int maxLength = 4096;

  /// Returns the canonical form of [raw] for [spec].
  ///
  /// An empty value means "not set" and returns `null`. A syntactically invalid
  /// value throws a [FormatException] whose message can be shown next to the
  /// field.
  static String? parse(ParameterSpec spec, String raw) {
    if (raw.isEmpty) {
      return null;
    }
    return switch (_shapeOf(spec)) {
      _Shape.boolean => _parseBoolean(raw),
      _Shape.integer => _parseInteger(raw),
      _Shape.decimal => _parseDecimal(raw),
      _Shape.enumeration => _parseEnumeration(spec, raw),
      _Shape.path || _Shape.text => raw,
      _Shape.pair => _parsePair(raw),
      _Shape.list => _parseList(spec, raw),
    };
  }

  /// Returns one message per problem with [raw], in a stable order.
  ///
  /// Path existence is checked only when [forStart] is true and a [pathExists]
  /// predicate is supplied; the domain layer does not touch the filesystem.
  static List<String> validate(
    ParameterSpec spec,
    String raw, {
    required bool forStart,
    bool Function(String path)? pathExists,
  }) {
    final shape = _shapeOf(spec);
    final label = _label(spec);

    if (raw.isEmpty) {
      return switch (shape) {
        _Shape.path || _Shape.text || _Shape.list || _Shape.pair => const [],
        _Shape.boolean => [
          '$label must be a boolean (true, false, 1, 0, on or off)',
        ],
        _Shape.integer => ['$label must be an integer'],
        _Shape.decimal => ['$label must be a number'],
        _Shape.enumeration => [
          '$label must be one of: ${spec.allowed.join(', ')}',
        ],
      };
    }

    final messages = <String>[];
    if (_hasControlChar(raw, allowNewline: _usesNewlineSeparator(shape))) {
      messages.add('$label must not contain control characters');
    }
    if (raw.length > maxLength) {
      messages.add('$label must be at most $maxLength characters');
    }

    final String? canonical;
    try {
      canonical = parse(spec, raw);
    } on FormatException catch (error) {
      messages.add('$label ${error.message}');
      return messages;
    }
    if (canonical == null) {
      return messages;
    }

    switch (shape) {
      case _Shape.integer:
        _checkBounds(messages, label, int.parse(canonical), spec.min, spec.max);
      case _Shape.decimal:
        _checkBounds(
          messages,
          label,
          double.parse(canonical),
          spec.min,
          spec.max,
        );
      case _Shape.path:
        _checkPath(messages, label, canonical, spec, forStart, pathExists);
      case _Shape.list:
        for (final item in canonical.split(_listSeparator(spec))) {
          if (spec.type == ParamValueType.path) {
            _checkPath(messages, label, item, spec, forStart, pathExists);
          }
        }
      case _Shape.pair:
        for (final item in canonical.split('\n')) {
          if (spec.type == ParamValueType.path) {
            _checkPath(messages, label, item, spec, forStart, pathExists);
          }
        }
      case _Shape.boolean || _Shape.enumeration || _Shape.text:
        break;
    }
    return messages;
  }

  /// Returns the canonical default for [spec], or an empty string when the
  /// upstream default is dynamic or unknown.
  static String formatDefault(ParameterSpec spec) {
    final value = spec.defaultValue;
    if (value == null) {
      return '';
    }
    return switch (spec.type) {
      ParamValueType.bool => value == true ? 'true' : 'false',
      ParamValueType.int => value.toString(),
      ParamValueType.double => _double(value),
      ParamValueType.enumeration ||
      ParamValueType.string ||
      ParamValueType.path => value.toString(),
    };
  }

  /// Whether [value] equals the effective default for [spec].
  ///
  /// A missing value counts as default: llama.cpp then applies its own
  /// default. A value is compared in canonical form, so `0.80` matches `0.8`.
  static bool isDefault(ParameterSpec spec, String? value) {
    if (value == null || value.isEmpty) {
      return true;
    }
    if (spec.defaultValue == null) {
      return false;
    }
    final String? canonical;
    try {
      canonical = parse(spec, value);
    } on FormatException {
      return false;
    }
    return canonical == formatDefault(spec);
  }

  static String _label(ParameterSpec spec) {
    if (spec.flags.isEmpty) {
      return spec.id;
    }
    return spec.flags.firstWhere(
      (flag) => flag.startsWith('--'),
      orElse: () => spec.flags.first,
    );
  }

  static _Shape _shapeOf(ParameterSpec spec) {
    if (spec.arity == 2) {
      return _Shape.pair;
    }
    if (spec.repeatable || spec.itemType != null) {
      return _Shape.list;
    }
    return switch (spec.type) {
      ParamValueType.bool => _Shape.boolean,
      ParamValueType.int => _Shape.integer,
      ParamValueType.double => _Shape.decimal,
      ParamValueType.enumeration => _Shape.enumeration,
      ParamValueType.path => _Shape.path,
      ParamValueType.string => _Shape.text,
    };
  }

  static bool _usesNewlineSeparator(_Shape shape) =>
      shape == _Shape.list || shape == _Shape.pair;

  static String _listSeparator(ParameterSpec spec) =>
      spec.repeatable ? '\n' : ',';

  static String _parseBoolean(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'true' || '1' || 'on':
        return 'true';
      case 'false' || '0' || 'off':
        return 'false';
      default:
        throw const FormatException(
          'must be a boolean (true, false, 1, 0, on or off)',
        );
    }
  }

  static String _parseInteger(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null) {
      throw const FormatException('must be an integer');
    }
    return value.toString();
  }

  static String _parseDecimal(String raw) {
    final value = double.tryParse(raw.trim());
    if (value == null) {
      throw const FormatException('must be a number');
    }
    if (!value.isFinite) {
      throw const FormatException('must be a finite number');
    }
    return value.toString();
  }

  static String _parseEnumeration(ParameterSpec spec, String raw) {
    final value = raw.trim();
    if (!spec.allowed.contains(value)) {
      throw FormatException('must be one of: ${spec.allowed.join(', ')}');
    }
    return value;
  }

  static String _parsePair(String raw) {
    final items = [
      for (final line in raw.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (items.length != 2) {
      throw const FormatException('requires two values separated by a newline');
    }
    return items.join('\n');
  }

  static String _parseList(ParameterSpec spec, String raw) {
    final separator = _listSeparator(spec);
    final items = <String>[];
    for (final item in raw.split(separator)) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) {
        throw const FormatException('must not contain empty list items');
      }
      items.add(_parseListItem(spec, trimmed));
    }
    if ((spec.itemType ?? spec.type) == ParamValueType.string &&
        items.any((item) => item.contains('='))) {
      for (final item in items) {
        final equals = item.indexOf('=');
        if (equals <= 0 || equals == item.length - 1) {
          throw const FormatException('must use key=value entries');
        }
      }
    }
    return items.join(separator);
  }

  static String _parseListItem(ParameterSpec spec, String item) =>
      switch (spec.itemType ?? spec.type) {
        ParamValueType.bool => _parseBoolean(item),
        ParamValueType.int => _parseInteger(item),
        ParamValueType.double => _parseDecimal(item),
        ParamValueType.enumeration => _parseEnumeration(spec, item),
        ParamValueType.string || ParamValueType.path => item,
      };

  static bool _hasControlChar(String value, {required bool allowNewline}) {
    for (final rune in value.runes) {
      if (rune == 0x0a && allowNewline) {
        continue;
      }
      if (rune < 0x20 || (rune >= 0x7f && rune <= 0x9f)) {
        return true;
      }
    }
    return false;
  }

  static void _checkBounds(
    List<String> messages,
    String label,
    num value,
    num? min,
    num? max,
  ) {
    if (min != null && max != null) {
      if (value < min || value > max) {
        messages.add('$label must be in $min..$max');
      }
    } else if (min != null) {
      if (value < min) {
        messages.add('$label must be at least $min');
      }
    } else if (max != null && value > max) {
      messages.add('$label must be at most $max');
    }
  }

  static void _checkPath(
    List<String> messages,
    String label,
    String path,
    ParameterSpec spec,
    bool forStart,
    bool Function(String path)? pathExists,
  ) {
    if (!spec.requiresExistingPath || !forStart || pathExists == null) {
      return;
    }
    if (!pathExists(path)) {
      messages.add('$label path does not exist: $path');
    }
  }

  static String _double(Object value) {
    if (value is double) {
      return value.toString();
    }
    if (value is int) {
      return '$value.0';
    }
    return value.toString();
  }
}

enum _Shape { boolean, integer, decimal, enumeration, path, text, pair, list }
