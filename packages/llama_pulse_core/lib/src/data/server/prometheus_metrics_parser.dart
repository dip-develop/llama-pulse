/// Numeric samples parsed from a Prometheus text exposition.
///
/// Parsing is deliberately tolerant: `# HELP`/`# TYPE` comments, blank lines,
/// labels and unparseable values are skipped instead of failing the snapshot.
final class PrometheusMetrics {
  /// Creates a sample set from already-parsed [samples].
  const PrometheusMetrics(this.samples);

  /// Last value seen for each metric name.
  final Map<String, double> samples;

  /// Returns the value of [name], or `0` when the metric is absent.
  double get(String name) => samples[name] ?? 0;

  /// Whether [name] was present in the exposition.
  bool has(String name) => samples.containsKey(name);

  /// Parses Prometheus text, keeping the last value of a duplicate name.
  ///
  /// Supports integers, decimals and scientific notation. `NaN` and infinite
  /// values are skipped because no counter can legitimately report them.
  static PrometheusMetrics parse(String text) {
    final samples = <String, double>{};
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) {
        continue;
      }
      final value = double.tryParse(parts.last);
      if (value == null || !value.isFinite) {
        continue;
      }
      var name = parts.first;
      final labelStart = name.indexOf('{');
      if (labelStart >= 0) {
        name = name.substring(0, labelStart);
      }
      name = name.trim();
      if (name.isEmpty) {
        continue;
      }
      samples[name] = value;
    }
    return PrometheusMetrics(samples);
  }
}
