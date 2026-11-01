import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:llama_pulse_core/src/data/inference/native/native_llama_session.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../support/native/fake_llama_builder.dart';

void main() {
  late String libraryPath;
  late FakeLlama fake;
  late Directory temp;
  late String modelPath;
  String? skipReason;

  setUpAll(() async {
    if (!await FakeLlamaBuilder.isAvailable) {
      skipReason = 'clang is not installed; the native shim needs a compiler';
      return;
    }
    libraryPath = await FakeLlamaBuilder.build();
    fake = FakeLlama(libraryPath);
  });

  setUp(() {
    if (skipReason != null) {
      return;
    }
    fake.reset();
    fake.setVersion('0.8.0');
    temp = Directory.systemTemp.createTempSync('llama_pulse_template_');
    modelPath = p.join(temp.path, 'tiny.gguf');
    File(modelPath).writeAsStringSync('not a real gguf');
  });

  tearDown(() {
    if (skipReason != null) {
      return;
    }
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  ModelParams params({String? chatTemplate, bool? useChatTemplate}) =>
      ModelParams.defaults().copyWith(
        modelPath: modelPath,
        contextSize: 4096,
        maxTokens: 4,
        chatTemplate: chatTemplate,
        useChatTemplate: useChatTemplate,
      );

  Future<NativeLlamaSession> loadedSession() async {
    final session = NativeLlamaSession(libraryPath: libraryPath);
    addTearDown(session.dispose);
    await session.open(libraryPath);
    await session.load(params());
    return session;
  }

  void begin(NativeLlamaSession session, ModelParams modelParams) {
    fake.setTokenizeResult(1);
    session.begin(
      GenerationRequest.create(
        requestId: 1,
        prompt: 'tell me a joke',
        params: modelParams,
      ),
    );
  }

  const templated =
      '<|im_start|>user\n'
      'tell me a joke'
      '<|im_end|>\n'
      '<|im_start|>assistant\n';

  test('applies the model template by default', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();

    begin(session, params());

    expect(fake.tokenizeText, templated);
    expect(fake.lastTemplateOutput, templated);
    expect(fake.tokenizeText, startsWith('<|im_start|>user'));
    expect(fake.tokenizeText, contains('tell me a joke'));
    expect(fake.tokenizeText, endsWith('<|im_start|>assistant\n'));
  });

  test('applies a named chatml template', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();

    begin(session, params(chatTemplate: 'chatml'));

    expect(fake.tokenizeText, templated);
  });

  test('useChatTemplate false sends the raw prompt', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();

    begin(session, params(useChatTemplate: false));

    expect(fake.tokenizeText, 'tell me a joke');
    expect(fake.lastTemplateOutput, isEmpty);
  });

  test('chatTemplate none sends the raw prompt', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();

    begin(session, params(chatTemplate: 'none'));

    expect(fake.tokenizeText, 'tell me a joke');
    expect(fake.lastTemplateOutput, isEmpty);
  });

  test(
    'an unknown template falls back to the raw prompt without throwing',
    () async {
      if (skipReason != null) {
        markTestSkipped(skipReason!);
        return;
      }
      final session = await loadedSession();

      begin(session, params(chatTemplate: 'unknown'));

      expect(fake.tokenizeText, 'tell me a joke');
      expect(fake.lastTemplateOutput, isEmpty);
    },
  );

  test('grows the prompt buffer when the template output is large', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();
    fake.setTemplatePad(1024);

    begin(session, params());

    expect(fake.lastTemplateOutputLen, greaterThan(1024));
    expect(fake.tokenizeText, fake.lastTemplateOutput);
    expect(fake.tokenizeText, startsWith('<|im_start|>user'));
    expect(fake.tokenizeText, endsWith('<|im_start|>assistant\n'));
  });
}
