/// Checks whether a TCP port can be bound on a host.
///
/// Test seam: the supervisor can inject a probe answer without sockets.
abstract interface class PortProbe {
  /// Returns true when [host] : [port] can be bound right now.
  Future<bool> isAvailable(String host, int port);
}
