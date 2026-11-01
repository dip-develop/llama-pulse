/// Parser for the `add_opt(common_arg(...))` blocks of upstream
/// `common/arg.cpp`.
///
/// The file is a C++ translation unit, not a data file, so this is a
/// brace/paren-aware scanner that understands string literals, raw strings,
/// character literals and comments. It deliberately does not tokenize the
/// whole language: it finds one block at a time, splits the argument list at
/// top-level commas and interprets the constructor shape documented in
/// `common/arg.h`.
///
/// The parser is pure Dart and does no IO; the generator and the coverage test
/// both feed it the vendored source text.
library;

/// One parsed `add_opt(common_arg(...))` definition.
final class UpstreamArgDefinition {
  /// Creates a definition.
  const UpstreamArgDefinition({
    required this.flags,
    required this.negatedFlags,
    required this.valueHints,
    required this.help,
    required this.handler,
    required this.arity,
    required this.examples,
    required this.excludes,
    required this.envVar,
    required this.isSampling,
    required this.isSpeculative,
    required this.isPresetOnly,
    required this.line,
  });

  /// Every positive flag token as written, for example `['-c',
  /// '--ctx-size']`.
  final List<String> flags;

  /// Every negated flag token as written, for example `['--no-perf']`.
  final List<String> negatedFlags;

  /// Literal value hints in declaration order, for example `['START',
  /// 'END']`.
  ///
  /// A hint that is an expression rather than a string literal (upstream has
  /// one: `common_speculative_all_types_str()`) is omitted here; [arity] still
  /// reports the value position.
  final List<String> valueHints;

  /// Help text with string literals concatenated and `%` placeholders kept.
  final String help;

  /// Upstream handler parameter type: `void`, `bool`, `int`, `string` or
  /// `str_str`.
  final String handler;

  /// Number of value positions the flag consumes.
  final int arity;

  /// `LLAMA_EXAMPLE_*` names with the prefix removed; defaults to `COMMON`
  /// because `common_arg` initialises it that way.
  final List<String> examples;

  /// `LLAMA_EXAMPLE_*` names the definition is excluded from.
  final List<String> excludes;

  /// Environment variable declared with `set_env`, if any.
  final String? envVar;

  /// Whether `set_sampling()` is chained.
  final bool isSampling;

  /// Whether `set_spec()` is chained.
  final bool isSpeculative;

  /// Whether `set_preset_only()` is chained.
  final bool isPresetOnly;

  /// One-based line of the `add_opt` token in the source file.
  final int line;

  /// Whether `llama-server`'s parser sees this definition.
  ///
  /// `add_opt` keeps an option when the current example is in `examples` or
  /// when it inherits `COMMON`, and the option is not excluded from it.
  bool get isVisibleToServer =>
      (examples.contains('SERVER') || examples.contains('COMMON')) &&
      !excludes.contains('SERVER');
}

/// One block the parser could not interpret.
final class UpstreamArgParseFailure {
  /// Creates a failure.
  const UpstreamArgParseFailure({
    required this.line,
    required this.message,
    required this.snippet,
  });

  /// One-based line where the block starts.
  final int line;

  /// What is wrong with the block.
  final String message;

  /// First characters of the block, for the error report.
  final String snippet;

  @override
  String toString() => 'arg.cpp:$line: $message ($snippet)';
}

/// Result of parsing an upstream `arg.cpp`.
final class UpstreamArgParseResult {
  /// Creates a parse result.
  const UpstreamArgParseResult({
    required this.definitions,
    required this.failures,
  });

  /// Successfully parsed definitions in declaration order.
  final List<UpstreamArgDefinition> definitions;

  /// Blocks that could not be parsed; the generator refuses to run when this
  /// list is not empty.
  final List<UpstreamArgParseFailure> failures;
}

const _blocksStart = 'add_opt(common_arg(';

/// Parses every `add_opt(common_arg(...))` block in [source].
///
/// Blocks that cannot be interpreted are reported in
/// [UpstreamArgParseResult.failures] instead of being skipped.
UpstreamArgParseResult parseUpstreamArgs(String source) {
  final cleaned = _blankComments(source);
  final lineStarts = _lineStarts(cleaned);
  final namedExamples = _namedExampleLists(cleaned);
  final definitions = <UpstreamArgDefinition>[];
  final failures = <UpstreamArgParseFailure>[];

  var index = 0;
  while (true) {
    final start = _nextBlockStart(cleaned, index);
    if (start == -1) {
      break;
    }
    final line = _lineFor(lineStarts, start);
    final snippet = cleaned
        .substring(start, _min(start + 80, cleaned.length))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    try {
      final open = start + _blocksStart.length - 1;
      final close = _matchingParen(cleaned, open);
      if (close == -1) {
        failures.add(
          UpstreamArgParseFailure(
            line: line,
            message: 'unterminated add_opt block',
            snippet: snippet,
          ),
        );
        break;
      }
      final chainEnd = _matchingParen(cleaned, start);
      if (chainEnd == -1) {
        failures.add(
          UpstreamArgParseFailure(
            line: line,
            message: 'unterminated add_opt call',
            snippet: snippet,
          ),
        );
        break;
      }
      definitions.add(
        _parseBlock(
          argsText: cleaned.substring(open + 1, close),
          chainText: cleaned.substring(close + 1, chainEnd),
          namedExamples: namedExamples,
          line: line,
        ),
      );
      index = chainEnd + 1;
    } on _BlockError catch (error) {
      failures.add(
        UpstreamArgParseFailure(
          line: line,
          message: error.message,
          snippet: snippet,
        ),
      );
      index = start + _blocksStart.length;
    }
  }

  return UpstreamArgParseResult(definitions: definitions, failures: failures);
}

/// Returns the one-based line of [index] in [source].
int _lineFor(List<int> lineStarts, int index) {
  var low = 0;
  var high = lineStarts.length - 1;
  while (low < high) {
    final middle = (low + high + 1) ~/ 2;
    if (lineStarts[middle] <= index) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  return low + 1;
}

List<int> _lineStarts(String source) {
  final starts = <int>[0];
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0a) {
      starts.add(i + 1);
    }
  }
  return starts;
}

int _min(int a, int b) => a < b ? a : b;

/// Finds the next block start outside comments and string literals.
int _nextBlockStart(String source, int from) {
  var i = from;
  while (i < source.length) {
    final stringEnd = _stringEnd(source, i);
    if (stringEnd > i) {
      i = stringEnd;
      continue;
    }
    if (source.startsWith(_blocksStart, i)) {
      return i;
    }
    i++;
  }
  return -1;
}

UpstreamArgDefinition _parseBlock({
  required String argsText,
  required String chainText,
  required Map<String, List<String>> namedExamples,
  required int line,
}) {
  final args = _splitTopLevel(argsText);
  if (args.isEmpty) {
    throw const _BlockError('common_arg has no arguments');
  }

  var cursor = 0;
  final flagsArg = args[cursor++];
  if (!_isBracedList(flagsArg)) {
    throw const _BlockError('first common_arg argument is not a flag list');
  }
  final flags = _stringLiterals(flagsArg);
  if (flags.isEmpty) {
    throw const _BlockError('flag list is empty');
  }

  var negated = const <String>[];
  if (cursor < args.length && _isBracedList(args[cursor])) {
    negated = _stringLiterals(args[cursor]);
    cursor++;
  }

  final remaining = args.sublist(cursor);
  if (remaining.isEmpty) {
    throw const _BlockError('common_arg has no handler');
  }
  final handlerArg = remaining.last;
  final handlerHead = _lambdaHead(handlerArg);
  if (handlerHead == null) {
    throw const _BlockError('last common_arg argument is not a lambda');
  }

  final middle = remaining.sublist(0, remaining.length - 1);
  final helpExpr = middle.isEmpty ? '' : middle.last;
  final hintExprs = middle.isEmpty
      ? const <String>[]
      : middle.sublist(0, middle.length - 1);

  final handler = _handlerKind(handlerHead);
  final hints = <String>[];
  for (final expr in hintExprs) {
    final text = _stringValue(expr);
    if (text != null) {
      hints.add(text);
    }
  }

  final help = helpExpr.isEmpty ? '' : (_stringValue(helpExpr) ?? '');
  final arity = switch (handler) {
    'void' || 'bool' => 0,
    'str_str' => 2,
    _ => hints.isEmpty ? 1 : hints.length,
  };

  return UpstreamArgDefinition(
    flags: flags,
    negatedFlags: negated,
    valueHints: hints,
    help: help,
    handler: handler,
    arity: arity,
    examples:
        _examples(chainText, 'set_examples', namedExamples) ?? const ['COMMON'],
    excludes: _examples(chainText, 'set_excludes', namedExamples) ?? const [],
    envVar: _env(chainText),
    isSampling: chainText.contains('set_sampling('),
    isSpeculative: chainText.contains('set_spec('),
    isPresetOnly: chainText.contains('set_preset_only('),
    line: line,
  );
}

bool _isBracedList(String text) {
  final trimmed = text.trim();
  return trimmed.startsWith('{') && trimmed.endsWith('}');
}

/// Collects named `initializer_list<enum llama_example>` variables.
///
/// Upstream shares the multimodal option set through `mmproj_examples`, so a
/// block can say `set_examples(mmproj_examples)` instead of spelling the names
/// out. Expanding the variable keeps the visibility decision honest.
Map<String, List<String>> _namedExampleLists(String source) {
  final lists = <String, List<String>>{};
  final pattern = RegExp(
    r'initializer_list<enum llama_example>\s+(\w+)\s*=\s*\{',
  );
  for (final match in pattern.allMatches(source)) {
    final open = match.end - 1;
    final close = _matchingParen(source, open);
    if (close == -1) {
      continue;
    }
    final text = source.substring(open + 1, close);
    lists[match.group(1)!] = [
      for (final token in RegExp(
        r'LLAMA_EXAMPLE_([A-Z0-9_]+)',
      ).allMatches(text))
        token.group(1)!,
    ];
  }
  return lists;
}

List<String>? _examples(
  String chain,
  String function,
  Map<String, List<String>> namedExamples,
) {
  final marker = '$function(';
  final start = chain.indexOf(marker);
  if (start == -1) {
    return null;
  }
  final open = start + marker.length - 1;
  final close = _matchingParen(chain, open);
  if (close == -1) {
    return null;
  }
  final text = chain.substring(open + 1, close);
  final names = <String>[];
  for (final match in RegExp(r'LLAMA_EXAMPLE_([A-Z0-9_]+)').allMatches(text)) {
    names.add(match.group(1)!);
  }
  if (names.isNotEmpty) {
    return names;
  }
  for (final entry in namedExamples.entries) {
    if (RegExp('\\b${entry.key}\\b').hasMatch(text)) {
      return entry.value;
    }
  }
  return names;
}

String? _env(String chain) {
  final match = RegExp(r'set_env\(\s*"((?:[^"\\]|\\.)*)"\s*\)')
      .firstMatch(chain);
  return match == null ? null : _unescape(match.group(1)!);
}

String _handlerKind(String head) {
  final parameters = _splitTopLevel(head.trim());
  if (parameters.isEmpty || parameters.first.trim().isEmpty) {
    return 'void';
  }
  if (parameters.length < 2) {
    return 'void';
  }
  final second = _parameterType(parameters[1]);
  if (second == 'std::string') {
    if (parameters.length >= 3 &&
        _parameterType(parameters[2]) == 'std::string') {
      return 'str_str';
    }
    return 'string';
  }
  if (second == 'int' || second == 'unsigned int' || second == 'size_t') {
    return 'int';
  }
  if (second == 'bool') {
    return 'bool';
  }
  throw _BlockError('unsupported handler parameter type: $second');
}

/// Extracts the type from a parameter declaration such as
/// `const std::string & value`.
String _parameterType(String declaration) {
  final normalized = declaration
      .replaceAll('const', ' ')
      .replaceAll('&', ' ')
      .replaceAll('*', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final match = RegExp(
    r'^(std::string|unsigned int|int|bool|float|double|size_t)\b',
  ).firstMatch(normalized);
  if (match == null) {
    throw _BlockError(
      'unsupported handler parameter declaration: $declaration',
    );
  }
  return match.group(1)!;
}

/// Returns the text between the parentheses of a lambda head, or `null`.
String? _lambdaHead(String expression) {
  final trimmed = expression.trimLeft();
  if (!trimmed.startsWith('[')) {
    return null;
  }
  final captureEnd = _matchingBracket(trimmed, 0, '[', ']');
  if (captureEnd == -1) {
    return null;
  }
  var i = captureEnd + 1;
  while (i < trimmed.length && _isWhitespace(trimmed.codeUnitAt(i))) {
    i++;
  }
  if (i >= trimmed.length || trimmed[i] != '(') {
    return null;
  }
  final close = _matchingParen(trimmed, i);
  if (close == -1) {
    return null;
  }
  return trimmed.substring(i + 1, close);
}

String? _stringValue(String expression) {
  final trimmed = expression.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('R"')) {
    return _rawStringValue(trimmed) ?? _literalsJoined(trimmed);
  }
  if (trimmed.startsWith('"')) {
    return _literalsJoined(trimmed);
  }
  if (trimmed.startsWith('string_format(') ||
      trimmed.startsWith('std::string(')) {
    final open = trimmed.indexOf('(');
    final close = _matchingParen(trimmed, open);
    if (close == -1) {
      return null;
    }
    final inner = trimmed.substring(open + 1, close);
    final first = _splitTopLevel(inner).first;
    return _stringValue(first);
  }
  // A ternary such as `ex == LLAMA_EXAMPLE_X ? "a" : "b"` describes the same
  // flag for several tools; the else branch is the general description.
  return _lastLiteral(trimmed);
}

String? _rawStringValue(String text) {
  final open = text.indexOf('(', 2);
  if (open == -1) {
    return null;
  }
  final delimiter = text.substring(2, open);
  final close = text.indexOf(')$delimiter"', open);
  if (close == -1) {
    return null;
  }
  return text.substring(open + 1, close);
}

String? _literalsJoined(String text) {
  final values = _stringLiterals(text);
  return values.isEmpty ? null : values.join();
}

String? _lastLiteral(String text) {
  final values = _stringLiterals(text);
  return values.isEmpty ? null : values.last;
}

/// Extracts every double-quoted literal in [text], in order.
List<String> _stringLiterals(String text) {
  final values = <String>[];
  var i = 0;
  while (i < text.length) {
    if (text[i] == 'R' && i + 1 < text.length && text[i + 1] == '"') {
      final end = _rawStringEnd(text, i);
      if (end == -1) {
        break;
      }
      final value = _rawStringValue(text.substring(i, end));
      if (value != null) {
        values.add(value);
      }
      i = end;
      continue;
    }
    if (text[i] == '"') {
      final end = _quotedEnd(text, i, '"');
      values.add(_unescape(text.substring(i + 1, end - 1)));
      i = end;
      continue;
    }
    if (text[i] == '\'') {
      i = _quotedEnd(text, i, '\'');
      continue;
    }
    i++;
  }
  return values;
}

/// Splits [text] at commas that are not nested in brackets or strings.
List<String> _splitTopLevel(String text) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  var i = 0;
  while (i < text.length) {
    final stringEnd = _stringEnd(text, i);
    if (stringEnd > i) {
      i = stringEnd;
      continue;
    }
    final unit = text.codeUnitAt(i);
    if (unit == 0x28 || unit == 0x5b || unit == 0x7b) {
      depth++;
    } else if (unit == 0x29 || unit == 0x5d || unit == 0x7d) {
      depth--;
    } else if (unit == 0x2c && depth == 0) {
      parts.add(text.substring(start, i).trim());
      start = i + 1;
    }
    i++;
  }
  parts.add(text.substring(start).trim());
  return parts;
}

/// Returns the index just past a string or character literal starting at [i],
/// or [i] when there is none.
int _stringEnd(String text, int i) {
  if (i >= text.length) {
    return i;
  }
  if (text[i] == 'R' &&
      i + 1 < text.length &&
      text[i + 1] == '"' &&
      (i == 0 || !_isIdentifierChar(text.codeUnitAt(i - 1)))) {
    final end = _rawStringEnd(text, i);
    return end == -1 ? i : end;
  }
  if (text[i] == '"') {
    return _quotedEnd(text, i, '"');
  }
  if (text[i] == '\'') {
    return _quotedEnd(text, i, '\'');
  }
  return i;
}

int _quotedEnd(String text, int start, String quote) {
  var i = start + 1;
  while (i < text.length) {
    if (text[i] == '\\') {
      i += 2;
      continue;
    }
    if (text[i] == quote) {
      return i + 1;
    }
    i++;
  }
  return text.length;
}

int _rawStringEnd(String text, int start) {
  final open = text.indexOf('(', start + 2);
  if (open == -1) {
    return -1;
  }
  final delimiter = text.substring(start + 2, open);
  final close = text.indexOf(')$delimiter"', open);
  return close == -1 ? -1 : close + delimiter.length + 2;
}

int _matchingParen(String text, int open) =>
    _matchingBracket(text, open, '(', ')');

int _matchingBracket(String text, int open, String opening, String closing) {
  var depth = 0;
  var i = open;
  while (i < text.length) {
    final stringEnd = _stringEnd(text, i);
    if (stringEnd > i) {
      i = stringEnd;
      continue;
    }
    if (text[i] == opening) {
      depth++;
    } else if (text[i] == closing) {
      depth--;
      if (depth == 0) {
        return i;
      }
    }
    i++;
  }
  return -1;
}

bool _isWhitespace(int unit) =>
    unit == 0x20 || unit == 0x09 || unit == 0x0a || unit == 0x0d;

bool _isIdentifierChar(int unit) =>
    (unit >= 0x30 && unit <= 0x39) ||
    (unit >= 0x41 && unit <= 0x5a) ||
    (unit >= 0x61 && unit <= 0x7a) ||
    unit == 0x5f;

/// Replaces comments with spaces while keeping indexes and line breaks intact.
String _blankComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final stringEnd = _stringEnd(source, i);
    if (stringEnd > i) {
      out.write(source.substring(i, stringEnd));
      i = stringEnd;
      continue;
    }
    if (source[i] == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (source[i] == '/' && i + 1 < source.length && source[i + 1] == '*') {
      final close = source.indexOf('*/', i + 2);
      final end = close == -1 ? source.length : close + 2;
      for (; i < end; i++) {
        out.write(source[i] == '\n' ? '\n' : ' ');
      }
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}

String _unescape(String text) {
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    if (text[i] != '\\' || i + 1 >= text.length) {
      out.write(text[i]);
      i++;
      continue;
    }
    final next = text[i + 1];
    switch (next) {
      case 'n':
        out.write('\n');
        i += 2;
      case 't':
        out.write('\t');
        i += 2;
      case 'r':
        out.write('\r');
        i += 2;
      case '0':
        out.write('\u0000');
        i += 2;
      case 'x':
        final hex = text.substring(i + 2, _min(i + 4, text.length));
        out.writeCharCode(int.parse(hex, radix: 16));
        i += 2 + hex.length;
      default:
        out.write(next);
        i += 2;
    }
  }
  return out.toString();
}

final class _BlockError implements Exception {
  const _BlockError(this.message);

  final String message;
}
