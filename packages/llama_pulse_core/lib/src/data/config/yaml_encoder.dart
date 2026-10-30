/// Emits plain Dart collections as YAML.
///
/// Hand-written because no maintained pure-Dart encoder quotes scalars
/// correctly for round-tripping. `yaml_writer` single-quotes every string and
/// leaves trailing spaces after block keys, which breaks byte-stable goldens.
///
/// Only maps, lists, `String`, `int`, `double`, `bool` and `null` are
/// supported. The output uses two-space indentation, `- ` list markers and a
/// single trailing newline; it never emits document markers, anchors, aliases
/// or tags.
abstract final class YamlEncoder {
  /// Encodes [data] as a YAML document.
  static String encode(Map<String, Object?> data) {
    final buffer = StringBuffer();
    _writeMap(buffer, data, 0, '', '');
    return buffer.toString();
  }

  static void _writeMap(
    StringBuffer out,
    Map<String, Object?> map,
    int keyIndent,
    String firstPrefix,
    String pathPrefix,
  ) {
    final padding = ' ' * keyIndent;
    var first = true;
    for (final entry in map.entries) {
      final lead = first ? firstPrefix : padding;
      first = false;
      _writeEntry(out, entry.key, entry.value, lead, keyIndent, pathPrefix);
    }
  }

  static void _writeEntry(
    StringBuffer out,
    String key,
    Object? value,
    String lead,
    int keyIndent,
    String pathPrefix,
  ) {
    final path = pathPrefix.isEmpty ? key : '$pathPrefix.$key';
    final label = '$lead${_string(key)}:';
    if (value is Map<String, Object?>) {
      if (value.isEmpty) {
        out.writeln('$label {}');
        return;
      }
      out.writeln(label);
      _writeMap(out, value, keyIndent + 2, ' ' * (keyIndent + 2), path);
      return;
    }
    if (value is List<Object?>) {
      if (value.isEmpty) {
        out.writeln('$label []');
        return;
      }
      out.writeln(label);
      _writeList(out, value, keyIndent + 2, ' ' * (keyIndent + 2), path);
      return;
    }
    out.writeln('$label ${_scalar(value, path)}');
  }

  static void _writeList(
    StringBuffer out,
    List<Object?> list,
    int indent,
    String firstPrefix,
    String pathPrefix,
  ) {
    final padding = ' ' * indent;
    for (var index = 0; index < list.length; index++) {
      final lead = index == 0 ? firstPrefix : padding;
      final item = list[index];
      final path = '$pathPrefix[$index]';
      if (item is Map<String, Object?>) {
        if (item.isEmpty) {
          out.writeln('$lead- {}');
        } else {
          _writeMap(out, item, indent + 2, '$lead- ', path);
        }
      } else if (item is List<Object?>) {
        if (item.isEmpty) {
          out.writeln('$lead- []');
        } else {
          out.writeln('$lead-');
          _writeList(out, item, indent + 2, ' ' * (indent + 2), path);
        }
      } else {
        out.writeln('$lead- ${_scalar(item, path)}');
      }
    }
  }

  static String _scalar(Object? value, String path) => switch (value) {
    null => 'null',
    final bool flag => flag ? 'true' : 'false',
    final int number => number.toString(),
    final double number => _double(number, path),
    final String text => _string(text),
    _ => throw ArgumentError(
      'Unsupported value at $path: ${value.runtimeType}',
    ),
  };

  static String _double(double value, String path) {
    if (!value.isFinite) {
      throw ArgumentError('Non-finite double at $path: $value');
    }
    final text = value.toString();
    if (text.contains('.')) {
      return text;
    }
    final exponent = text.indexOf(RegExp('[eE]'));
    if (exponent == -1) {
      return '$text.0';
    }
    return '${text.substring(0, exponent)}.0${text.substring(exponent)}';
  }

  static String _string(String value) {
    if (!_needsQuotes(value)) {
      return value;
    }
    return "'${value.replaceAll("'", "''")}'";
  }

  static bool _needsQuotes(String value) {
    if (value.isEmpty) {
      return true;
    }
    if (value != value.trim()) {
      return true;
    }
    if (_reservedWords.contains(value.toLowerCase())) {
      return true;
    }
    if (_looksNumeric(value)) {
      return true;
    }
    if (_indicators.contains(value[0])) {
      return true;
    }
    if (value.contains("'")) {
      return true;
    }
    return value.contains(': ') || value.contains(' #');
  }

  static bool _looksNumeric(String value) {
    if (_numberPattern.hasMatch(value) ||
        _specialNumberPattern.hasMatch(value)) {
      return true;
    }
    return num.tryParse(value) != null;
  }

  static const Set<String> _reservedWords = {
    'true',
    'false',
    'null',
    '~',
    'yes',
    'no',
    'on',
    'off',
  };

  static const Set<String> _indicators = {
    '-',
    '?',
    ':',
    ',',
    '[',
    ']',
    '{',
    '}',
    '#',
    '&',
    '*',
    '!',
    '|',
    '>',
    "'",
    '"',
    '%',
    '@',
    '`',
  };

  static final RegExp _numberPattern = RegExp(
    r'^[-+]?(?:0[xX][0-9a-fA-F]+|0[oO][0-7]+|(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][-+]?[0-9]+)?)$',
  );
  static final RegExp _specialNumberPattern = RegExp(
    r'^[-+]?\.(?:inf|nan)$',
    caseSensitive: false,
  );
}
