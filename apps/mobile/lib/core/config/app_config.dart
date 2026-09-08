/// Runtime configuration for FutBolia mobile (Phase 1).
class AppConfig {
  static const String appName = 'FutBolia';

  /// Android emulator → host machine loopback.
  /// Physical device: replace with your LAN IP.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );
}
