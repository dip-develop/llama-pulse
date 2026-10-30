import 'dart:convert';

import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Writes [value] as a single-line JSON object.
void writeJsonLine(StringSink sink, Map<String, Object?> value) =>
    sink.writeln(jsonEncode(value));

/// Writes a params document as YAML, or as a single-line JSON object.
///
/// The YAML branch is the exact text the repository stores on disk, so it can
/// be redirected straight into `params.yaml`.
void writeParamsDocument(
  StringSink sink,
  Map<String, Object?> document, {
  required bool json,
}) {
  if (json) {
    writeJsonLine(sink, document);
  } else {
    sink.write(YamlEncoder.encode(document));
  }
}

/// Formats [bytes] as mebibytes with two decimals.
String formatSizeMiB(int bytes) => (bytes / 1048576).toStringAsFixed(2);
