import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  CliServices makeServices() => CliServices(
    paths: const AppPaths(configDirectory: '/config/llamapulse'),
    configStore: InMemoryConfigStore(),
    out: StringBuffer(),
    err: StringBuffer(),
    watchInterrupts: true,
  );

  test('interrupts is a broadcast stream with overlapping listeners', () async {
    final services = makeServices();
    addTearDown(services.dispose);

    final stream = services.interrupts;
    expect(stream, isNotNull);
    expect(stream!.isBroadcast, isTrue);

    final first = stream.listen((_) {});
    final second = stream.listen((_) {});
    await first.cancel();
    // A cancelled listener must not close the stream for the remaining or for
    // any later listener.
    final third = stream.listen((_) {});
    await second.cancel();
    await third.cancel();
  });

  test('interrupts can be listened to again after the last cancel', () async {
    final services = makeServices();
    addTearDown(services.dispose);

    final first = services.interrupts!.listen((_) {});
    await first.cancel();
    final second = services.interrupts!.listen((_) {});
    await second.cancel();
  });

  test('dispose is idempotent and stops watching signals', () async {
    final services = makeServices();
    final subscription = services.interrupts!.listen((_) {});
    await subscription.cancel();

    await services.dispose();
    await services.dispose();
  });
}
