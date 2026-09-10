import 'dart:convert';

/// Reads `exp` from a JWT payload without verifying the signature.
DateTime? jwtExpiry(String? token) {
  if (token == null || token.isEmpty) return null;
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return null;
    final exp = payload['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    }
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (exp * 1000).round(),
        isUtc: true,
      );
    }
    return null;
  } catch (_) {
    return null;
  }
}

bool jwtIsExpiredOrNear(
  String? token, {
  Duration skew = const Duration(seconds: 45),
}) {
  if (token == null || token.isEmpty) return true;
  final exp = jwtExpiry(token);
  if (exp == null) return false;
  return DateTime.now().toUtc().isAfter(exp.subtract(skew));
}

/// When to refresh before the access token dies. Fallback: 12 minutes.
Duration delayUntilJwtRefresh(String? token) {
  final exp = jwtExpiry(token);
  if (exp == null) return const Duration(minutes: 12);
  final wait = exp
      .subtract(const Duration(minutes: 1))
      .difference(DateTime.now().toUtc());
  if (wait.isNegative) return const Duration(seconds: 2);
  return wait;
}
