/// Canonical body and digest for the generated parameter catalog.
///
/// The digest covers the catalog body (`source`, `groups` and `parameters`)
/// without the digest field itself, so a hand edit to the generated YAML is
/// detected by regenerating it. The canonical form is a length-prefixed text
/// tree: it does not depend on YAML quoting, key order or platform newlines.
///
/// The hash function is injected so this library stays runtime-dependency free;
/// the generator and the tests pass `package:crypto`'s SHA-256.
library;

import 'dart:convert';

/// Computes the canonical text of a catalog body.
///
/// Maps are written with sorted keys and every scalar is length-prefixed
/// where it is not self-delimiting, so two semantically equal bodies always
/// produce the same text.
String canonicalCatalogBody(Map<String, Object?> body) {
  final out = StringBuffer();
  _writeCanonical(out, body);
  return out.toString();
}

/// Computes the catalog digest for [body].
///
/// [digest] receives the UTF-8 bytes of the canonical body and returns the
/// lowercase hexadecimal SHA-256 digest.
String catalogDigest(
  Map<String, Object?> body,
  String Function(List<int> bytes) digest,
) => 'sha256:${digest(utf8.encode(canonicalCatalogBody(body)))}';

void _writeCanonical(StringBuffer out, Object? value) {
  switch (value) {
    case null:
      out.write('~');
    case final bool flag:
      out.write(flag ? 'T' : 'F');
    case final int number:
      out
        ..write('i')
        ..write(number);
    case final double number:
      out
        ..write('d')
        ..write(number.toString());
    case final String text:
      out
        ..write('s')
        ..write(text.length)
        ..write(':')
        ..write(text);
    case final List<Object?> list:
      out.write('[');
      for (final item in list) {
        _writeCanonical(out, item);
        out.write(',');
      }
      out.write(']');
    case final Map<Object?, Object?> map:
      final keys = map.keys.map((key) => key.toString()).toList()..sort();
      out.write('{');
      for (final key in keys) {
        _writeCanonical(out, key);
        out.write('=');
        _writeCanonical(out, map[key]);
        out.write(';');
      }
      out.write('}');
    default:
      throw ArgumentError('unsupported canonical value: ${value.runtimeType}');
  }
}
