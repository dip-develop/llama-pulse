import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  const probe = SocketPortProbe();

  test('reports a bound port as unavailable', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(socket.close);

    expect(await probe.isAvailable('127.0.0.1', socket.port), isFalse);
  });

  test('reports a released port as available', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();

    expect(await probe.isAvailable('127.0.0.1', port), isTrue);
  });
}
