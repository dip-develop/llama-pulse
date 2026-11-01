import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

const _source = r'''
static const std::vector<common_arg> & defs() {
    static const std::initializer_list<enum llama_example> shared = {
        LLAMA_EXAMPLE_MTMD,
        LLAMA_EXAMPLE_SERVER,
    };
    add_opt(common_arg(
        {"-c", "--ctx-size"}, "N",
        string_format("size of the prompt context (default: %d, 0 = model)", params.n_ctx),
        [](common_params & params, int value) {
            params.n_ctx = value;
        }
    ).set_env("LLAMA_ARG_CTX_SIZE"));
    add_opt(common_arg(
        {"--perf"}, {"--no-perf"},
        // a comment with a comma, a brace { and a paren (
        "whether to enable timings",
        [](common_params & params, bool value) {
            params.no_perf = !value;
        }
    ));
    add_opt(common_arg(
        {"--control-vector-layer-range"}, "START", "END",
        "layer range to apply, start and end inclusive",
        [](common_params & params, const std::string & begin,
           const std::string & end) {
            (void) params; (void) begin; (void) end;
        }
    ));
    add_opt(common_arg(
        {"--grammar"}, "GRAMMAR",
        "BNF grammar \"quoted\" and an escaped quote: \"x\"\n"
        "second line",
        [](common_params & params, const std::string & value) {
            params.grammar = value;
        }
    ));
    add_opt(common_arg(
        {"--helper"}, "MODEL",
        R"(a raw string with // and ( and ) and "quotes")",
        [](common_params & params, const std::string & value) {
            params.model.path = value;
        }
    ).set_examples(shared));
    add_opt(common_arg(
        {"-np", "--parallel"}, "N",
        "number of server slots",
        [](common_params & params, int value) {
            params.n_parallel = value;
        }
    ).set_examples({LLAMA_EXAMPLE_SERVER}));
    add_opt(common_arg(
        {"-np", "--parallel"}, "N",
        "number of parallel sequences",
        [](common_params & params, int value) {
            params.n_parallel = value;
        }
    ));
}
''';

void main() {
  final result = parseUpstreamArgs(_source);

  test('parses every block of a synthetic translation unit', () {
    expect(result.failures, isEmpty, reason: result.failures.join('\n'));
    expect(result.definitions, hasLength(7));
  });

  test('reads flags, hints, help and env vars', () {
    final ctx = result.definitions.first;
    expect(ctx.flags, ['-c', '--ctx-size']);
    expect(ctx.valueHints, ['N']);
    expect(ctx.handler, 'int');
    expect(ctx.arity, 1);
    expect(ctx.help, contains('%d'));
    expect(ctx.envVar, 'LLAMA_ARG_CTX_SIZE');
    expect(ctx.examples, ['COMMON']);
    expect(ctx.line, greaterThan(0));
  });

  test('reads negated flags and boolean handlers', () {
    final perf = result.definitions[1];
    expect(perf.flags, ['--perf']);
    expect(perf.negatedFlags, ['--no-perf']);
    expect(perf.handler, 'bool');
    expect(perf.arity, 0);
  });

  test('reads two value hints and string handlers', () {
    final range = result.definitions[2];
    expect(range.valueHints, ['START', 'END']);
    expect(range.handler, 'str_str');
    expect(range.arity, 2);
  });

  test('keeps escaped quotes and concatenates literals', () {
    final grammar = result.definitions[3];
    expect(grammar.help, contains('"quoted"'));
    expect(grammar.help, contains('\nsecond line'));
  });

  test('does not treat a raw string as a comment or a paren', () {
    final helper = result.definitions[4];
    expect(helper.help, 'a raw string with // and ( and ) and "quotes"');
    expect(helper.examples, ['MTMD', 'SERVER']);
    expect(helper.isVisibleToServer, isTrue);
  });

  test('keeps duplicate flag sets apart by examples', () {
    final duplicates = result.definitions
        .where((definition) => definition.flags.contains('--parallel'))
        .toList();
    expect(duplicates, hasLength(2));
    expect(duplicates.first.examples, ['SERVER']);
    expect(duplicates.last.examples, ['COMMON']);
    expect(duplicates.first.help, 'number of server slots');
  });

  test('reports an unparseable block with its line', () {
    final broken = parseUpstreamArgs('''
class X {
  void f() {
    add_opt(common_arg(
      {"--oops"},
      "help"
    ));
  }
}
''');
    expect(broken.failures, hasLength(1));
    expect(broken.failures.single.line, 3);
    expect(broken.failures.single.message, contains('lambda'));
  });
}
