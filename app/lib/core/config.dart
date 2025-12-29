/// App configuration
class AppConfig {
  /// WebSocket server URL
  /// Set via --dart-define=WS_URL=... at build time
  /// Default: localhost for local dev
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8405',
  );

  /// Whether we're in debug mode
  static const bool isDebug = bool.fromEnvironment('DEBUG', defaultValue: true);
}
