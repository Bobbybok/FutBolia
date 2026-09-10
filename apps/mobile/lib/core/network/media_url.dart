import '../config/app_config.dart';

String? apiMediaUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  final suffix = path.startsWith('/') ? path : '/$path';
  return '${AppConfig.apiBaseUrl}$suffix';
}
