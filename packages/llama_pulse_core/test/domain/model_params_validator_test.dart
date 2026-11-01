import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  const validator = ModelParamsValidator();

  ModelParams withTemplate(String? template) =>
      ModelParams.defaults().copyWith(chatTemplate: template);

  test('the defaults are valid', () {
    expect(validator.validate(ModelParams.defaults()), isEmpty);
  });

  test('null and none are accepted without a length or control check', () {
    expect(validator.validate(withTemplate(null)), isEmpty);
    expect(validator.validate(withTemplate('none')), isEmpty);
  });

  test('a named template up to 64 characters is accepted', () {
    expect(validator.validate(withTemplate('chatml')), isEmpty);
    expect(validator.validate(withTemplate('a' * 64)), isEmpty);
  });

  test('an empty or overlong template is rejected', () {
    expect(validator.validate(withTemplate('')), [
      'chatTemplate must be 1..64 characters',
    ]);
    expect(validator.validate(withTemplate('a' * 65)), [
      'chatTemplate must be 1..64 characters',
    ]);
  });

  test('control characters are rejected', () {
    expect(validator.validate(withTemplate('chat\nml')), [
      'chatTemplate must not contain control characters',
    ]);
    expect(validator.validate(withTemplate('chat\u007fml')), [
      'chatTemplate must not contain control characters',
    ]);
  });

  test('useChatTemplate has no constraint', () {
    expect(
      validator.validate(
        ModelParams.defaults().copyWith(useChatTemplate: false),
      ),
      isEmpty,
    );
    expect(
      validator.validate(
        ModelParams.defaults().copyWith(useChatTemplate: true),
      ),
      isEmpty,
    );
  });
}
