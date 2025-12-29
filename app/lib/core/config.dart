/// App configuration
class AppConfig {
  /// WebSocket server URL
  /// Change this based on environment:
  /// - Local dev: ws://localhost:8405
  /// - Production: ws://209.38.85.244:8405
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8405',
  );

  /// Whether we're in debug mode
  static const bool isDebug = bool.fromEnvironment('DEBUG', defaultValue: true);
}
