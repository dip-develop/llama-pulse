import 'dart:io';

import '../../domain/gateways/port_probe.dart';

/// Probes ports by binding a [ServerSocket] and closing it immediately.
///
/// The answer is advisory: the port can be taken between the probe and the
/// bind, so the supervisor also maps child stderr bind errors.
final class SocketPortProbe implements PortProbe {
  /// Creates a probe.
  const SocketPortProbe();

  @override
  Future<bool> isAvailable(String host, int port) async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(host, port);
      return true;
    } catch (_) {
      return false;
    } finally {
      await socket?.close();
    }
  }
}
