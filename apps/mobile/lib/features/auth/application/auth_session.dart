import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/auth/jwt_expiry.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/realtime/session_keep_alive.dart';
import '../../../core/realtime/socket_service.dart';
import '../domain/futbolia_user.dart';

class AuthSession extends ChangeNotifier {
  AuthSession({
    ApiClient? apiClient,
    FlutterSecureStorage? storage,
    bool Function()? notificationsEnabled,
  })  : _api = apiClient ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage(),
        _notificationsEnabled = notificationsEnabled ?? (() => true) {
    _api.onUnauthorized = _silentRefresh;
    _api.onAccessTokenChanged = (token) {
      SocketService.instance.updateToken(token);
    };
    SocketService.instance.tokenProvider = () => _api.accessToken;
    SocketService.instance.refreshAuth = _silentRefresh;
  }

  final ApiClient _api;
  final FlutterSecureStorage _storage;
  final bool Function() _notificationsEnabled;

  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshToken';
  static const _kUser = 'userJson';

  ApiClient get api => _api;

  FutBoliaUser? user;
  bool bootstrapping = true;
  String? errorMessage;
  String? pendingEmailVerificationToken;
  bool promptEmailVerification = false;
  Future<bool>? _refreshInFlight;
  bool _refreshRejected = false;

  bool get isAuthenticated => user != null;

  bool consumePromptEmailVerification() {
    if (!promptEmailVerification) return false;
    promptEmailVerification = false;
    return true;
  }

  /// Restore session from secure storage on app launch.
  Future<void> bootstrap() async {
    bootstrapping = true;
    notifyListeners();
    try {
      final access = await _storage.read(key: _kAccess);
      final refresh = await _storage.read(key: _kRefresh);
      final cachedUser = await _storage.read(key: _kUser);

      if ((access == null || access.isEmpty) &&
          (refresh == null || refresh.isEmpty)) {
        user = null;
        return;
      }

      // Show last known user immediately while we validate with the API.
      if (cachedUser != null && cachedUser.isNotEmpty) {
        try {
          user = FutBoliaUser.fromJson(
            Map<String, dynamic>.from(jsonDecode(cachedUser) as Map),
          );
        } catch (_) {
          user = null;
        }
      }

      if (access != null && access.isNotEmpty) {
        _api.setAccessToken(access);
      }

      try {
        final hasAccess = access != null && access.isNotEmpty;
        final accessExpired = jwtIsExpiredOrNear(access);
        await _hydrateFromNetwork(
          preferRefresh: !hasAccess || accessExpired,
        );
      } on ApiException catch (e) {
        if ((e.statusCode == 401 || e.statusCode == 403) &&
            _refreshRejected) {
          await _clearTokens();
          user = null;
        }
        // Network / cold start / expired access with a still-valid refresh:
        // keep cached user + tokens.
      } catch (_) {
        // Keep local session if the API is briefly unreachable.
      }
      if (user != null && _api.accessToken != null) {
        await _startRealtime();
      }
    } finally {
      bootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> _hydrateFromNetwork({required bool preferRefresh}) async {
    if (preferRefresh) {
      final ok = await _silentRefresh();
      if (ok) {
        await _loadMeOrKeepCached();
        return;
      }
      if (_refreshRejected) {
        throw ApiException('Session expirée', statusCode: 401);
      }
      await _loadMeOrKeepCached();
      return;
    }

    try {
      await _loadMeOrKeepCached(required: true);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        final ok = await _silentRefresh();
        if (ok) {
          await _loadMeOrKeepCached();
          return;
        }
        if (!_refreshRejected) return;
        rethrow;
      }
      rethrow;
    }
  }

  Future<void> _loadMeOrKeepCached({bool required = false}) async {
    try {
      final me = await _api.getMe();
      user = FutBoliaUser.fromJson(me);
      await _storage.write(key: _kUser, value: jsonEncode(me));
    } on ApiException catch (e) {
      if (!required && (e.statusCode != 401 && e.statusCode != 403)) {
        return;
      }
      if (!required && !_refreshRejected) return;
      rethrow;
    } catch (_) {
      if (required) rethrow;
    }
  }

  /// Returns true if a new access token was obtained.
  Future<bool> _silentRefresh() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final future = _silentRefreshOnce().whenComplete(() {
      _refreshInFlight = null;
    });
    _refreshInFlight = future;
    return future;
  }

  Future<bool> _silentRefreshOnce() async {
    final refresh = await _storage.read(key: _kRefresh);
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final data = await _api.refresh(refresh);
      await _persistSession(data, connectRealtime: false);
      debugPrint('JWT refresh OK');
      _refreshRejected = false;
      return true;
    } on ApiException catch (e) {
      debugPrint('JWT refresh failed: ${e.statusCode} ${e.message}');
      if (e.statusCode == 401 || e.statusCode == 403) {
        _refreshRejected = true;
        return false;
      }
      return false;
    } catch (e) {
      debugPrint('JWT refresh failed: $e');
      return false;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String pseudo,
  }) async {
    errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.register(
        email: email.trim(),
        password: password,
        pseudo: pseudo.trim(),
      );
      await _persistSession(data);
      pendingEmailVerificationToken =
          data['devEmailVerificationToken'] as String?;
      promptEmailVerification = data['emailVerificationRequired'] == true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      rethrow;
    } catch (e) {
      errorMessage = 'Inscription impossible: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> login({
    String? email,
    String? pseudo,
    required String password,
  }) async {
    errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.login(
        email: email?.trim(),
        pseudo: pseudo?.trim(),
        password: password,
      );
      await _persistSession(data);
      pendingEmailVerificationToken = null;
    } on ApiException catch (e) {
      errorMessage = e.message;
      rethrow;
    } catch (e) {
      errorMessage = 'Connexion impossible: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> verifyEmail(String token) async {
    errorMessage = null;
    notifyListeners();
    try {
      await _api.verifyEmail(token.trim());
      final me = await _api.getMe();
      user = FutBoliaUser.fromJson(me);
      await _storage.write(key: _kUser, value: jsonEncode(me));
      pendingEmailVerificationToken = null;
    } on ApiException catch (e) {
      errorMessage = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<String?> resendVerification() async {
    errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.resendVerification();
      final code = data['devEmailVerificationToken'] as String?;
      if (code != null) {
        pendingEmailVerificationToken = code;
      }
      return data['message'] as String? ?? 'Code renvoyé';
    } on ApiException catch (e) {
      errorMessage = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> body) async {
    errorMessage = null;
    notifyListeners();
    try {
      final me = await _api.updateMe(body);
      user = FutBoliaUser.fromJson(me);
      await _storage.write(key: _kUser, value: jsonEncode(me));
    } on ApiException catch (e) {
      errorMessage = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> uploadAvatar({
    required List<int> bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) async {
    errorMessage = null;
    notifyListeners();
    try {
      final me = await _api.uploadMyAvatar(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      );
      user = FutBoliaUser.fromJson(me);
      await _storage.write(key: _kUser, value: jsonEncode(me));
    } on ApiException catch (e) {
      errorMessage = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final refresh = await _storage.read(key: _kRefresh);
    try {
      if (refresh != null) {
        await _api.logout(refresh);
      }
    } catch (_) {
      // Local logout still proceeds.
    }
    await PushNotificationService.instance.stop(_api);
    SessionKeepAlive.instance.stop();
    SocketService.instance.disconnect();
    await _clearTokens();
    user = null;
    pendingEmailVerificationToken = null;
    notifyListeners();
  }

  Future<void> _persistSession(
    Map<String, dynamic> data, {
    bool connectRealtime = true,
  }) async {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access == null || refresh == null) {
      throw ApiException('Réponse d’authentification incomplète');
    }
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    _api.setAccessToken(access);

    final rawUser = data['user'];
    if (rawUser is Map) {
      final userMap = Map<String, dynamic>.from(rawUser);
      await _storage.write(key: _kUser, value: jsonEncode(userMap));
      user = FutBoliaUser.fromJson(userMap);
    } else if (user == null) {
      throw ApiException('Réponse utilisateur invalide');
    }

    if (connectRealtime) {
      await _startRealtime();
    } else {
      SocketService.instance.updateToken(access);
      SessionKeepAlive.instance.noteTokenRefresh();
    }
  }

  Future<void> _startRealtime() async {
    SocketService.instance.connect(_api.accessToken);
    SessionKeepAlive.instance.attach(
      api: _api,
      refreshJwt: _silentRefresh,
      token: () => _api.accessToken,
    );
    if (_notificationsEnabled()) {
      await PushNotificationService.instance.start(_api);
    }
  }

  Future<void> _clearTokens() async {
    _api.setAccessToken(null);
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
  }
}
