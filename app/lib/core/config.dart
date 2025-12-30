/// App configuration
class AppConfig {
  /// Droplet IP address
  static const String dropletIp = '209.38.85.244';

  /// WebSocket server URL
  /// Set via --dart-define=WS_URL=... at build time
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://$dropletIp:8405',
  );

  /// Update server URL for self-hosted OTA
  /// Set via --dart-define=UPDATE_URL=... at build time
  static const String updateUrl = String.fromEnvironment(
    'UPDATE_URL',
    defaultValue: 'http://$dropletIp:8406',
  );

  /// Current app version (injected at build time)
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.1.0',
  );

  /// Whether we're in debug mode
  static const bool isDebug = bool.fromEnvironment('DEBUG', defaultValue: true);
}
