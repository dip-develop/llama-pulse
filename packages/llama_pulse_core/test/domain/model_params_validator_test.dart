import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  const validator = ModelParamsValidator();

  ModelParams withTemplate(String? template) =>
      ModelParams.defaults().copyWith(chatTemplate: template);

  ModelParams withSystemPrompt(String? prompt) =>
      ModelParams.defaults().copyWith(systemPrompt: prompt);

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

  test('a null system prompt is accepted', () {
    expect(validator.validate(withSystemPrompt(null)), isEmpty);
  });

  test('a system prompt at the length limit is accepted', () {
    expect(
      validator.validate(
        withSystemPrompt('a' * ModelParamLimits.maxSystemPromptLength),
      ),
      isEmpty,
    );
  });

  test('a system prompt one character over the limit is rejected', () {
    expect(
      validator.validate(
        withSystemPrompt('a' * (ModelParamLimits.maxSystemPromptLength + 1)),
      ),
      ['systemPrompt must be at most 4096 characters'],
    );
  });

  test('a blank system prompt is rejected', () {
    expect(validator.validate(withSystemPrompt('   ')), [
      'systemPrompt must not be blank',
    ]);
  });

  test('a multi-line system prompt is accepted', () {
    expect(
      validator.validate(
        withSystemPrompt('You are terse.\nAnswer in one line.\n\tBe kind.'),
      ),
      isEmpty,
    );
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
