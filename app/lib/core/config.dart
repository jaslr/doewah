/// App configuration
class AppConfig {
  /// WebSocket server URL
  /// Set via --dart-define=WS_URL=... at build time
  /// Default: localhost for local dev
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8405',
  );

  /// Update server URL for self-hosted OTA
  /// Set via --dart-define=UPDATE_URL=... at build time
  static const String updateUrl = String.fromEnvironment(
    'UPDATE_URL',
    defaultValue: 'http://localhost:8406',
  );

  /// Current app version (injected at build time)
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.1.0',
  );

  /// Whether we're in debug mode
  static const bool isDebug = bool.fromEnvironment('DEBUG', defaultValue: true);
}
