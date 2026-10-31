/// Names of the configuration documents the app stores.
abstract final class ConfigNames {
  /// Startup and sampling parameters; maps to `params.yaml`.
  static const String params = 'params';

  /// Supervised server launch configuration; maps to `server.yaml`.
  static const String server = 'server';

  /// Supervised server state snapshot; maps to `server-state.yaml`.
  static const String serverState = 'server-state';
}
