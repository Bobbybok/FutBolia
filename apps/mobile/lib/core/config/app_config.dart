/// Runtime configuration for FutBolia mobile (Phase 1).
class AppConfig {
  static const String appName = 'FutBolia';

  /// Online API (Render free). Override locally with:
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1`
  /// or `.\scripts\launch-phone.ps1 -Local` (LAN NestJS).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://futbolia-api.onrender.com/api/v1',
  );

  /// Socket.io origin (same host as the API, without `/api/v1`).
  static String get socketUrl {
    final base = apiBaseUrl;
    if (base.endsWith('/api/v1')) {
      return base.substring(0, base.length - '/api/v1'.length);
    }
    if (base.endsWith('/api/v1/')) {
      return base.substring(0, base.length - '/api/v1/'.length);
    }
    return base;
  }
}
