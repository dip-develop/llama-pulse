import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  const validator = ParameterValidator();

  List<String> validate(
    Map<String, String> values, {
    ParamSurface surface = ParamSurface.server,
    bool forStart = false,
  }) => validator.validateValues(
    BuiltMap<String, String>(values),
    surface: surface,
    forStart: forStart,
  );

  test('accepts configurable values', () {
    expect(
      validate({'temp': '0.5', 'pooling': 'mean', 'chat-template': '{{x}}'}),
      isEmpty,
    );
  });

  test('reports an unknown id with the catalog hint', () {
    expect(validate({'unknown': '1'}), [
      "unknown parameter 'unknown' (run `llamapulse params catalog`)",
    ]);
  });

  test('rejects a managed id', () {
    expect(validate({'ctx-size': '8192'}), [
      "'ctx-size' is managed by ServerConfig",
    ]);
  });

  test('rejects an unsupported id with its reason', () {
    final reason = ParameterCatalog.v080.byId('help')?.reason;
    expect(validate({'help': 'true'}), ["'help' is not supported: $reason"]);
  });

  test('rejects a removed id with its replacement', () {
    expect(validate({'draft': '4'}), [
      "'draft' was removed; use --spec-draft-n-max or "
          '--spec-ngram-mod-n-max instead',
    ]);
  });

  test('rejects a server-only id on the embedded surface', () {
    expect(validate({'threads-batch': '2'}, surface: ParamSurface.embedded), [
      "'threads-batch' is not available for embedded",
    ]);
  });

  test('reports codec errors', () {
    expect(validate({'pooling': 'Mean'}), [
      '--pooling must be one of: none, mean, cls, last, rank',
    ]);
  });

  test('reports catalog order, then unknown ids sorted', () {
    expect(
      validate({'zzz': '1', 'pooling': 'Mean', 'aaa': '2', 'top-k': 'x'}),
      [
        '--top-k must be an integer',
        '--pooling must be one of: none, mean, cls, last, rank',
        "unknown parameter 'aaa' (run `llamapulse params catalog`)",
        "unknown parameter 'zzz' (run `llamapulse params catalog`)",
      ],
    );
  });

  test('checks path existence only for a start', () {
    expect(validate({'grammar-file': '/missing.gbnf'}), isEmpty);

    final startValidator = ParameterValidator(pathExists: (_) => false);
    expect(
      startValidator.validateValues(
        BuiltMap<String, String>({'grammar-file': '/missing.gbnf'}),
        surface: ParamSurface.server,
        forStart: true,
      ),
      ['--grammar-file path does not exist: /missing.gbnf'],
    );
  });
}
