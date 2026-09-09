import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/push_notification_service.dart';
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
        await _hydrateFromNetwork(preferRefresh: !hasAccess);
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          await _clearTokens();
          user = null;
        }
        // Network / cold start: keep cached user + tokens.
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
      if (!ok) {
        throw ApiException('Session expirée', statusCode: 401);
      }
      return;
    }

    try {
      final me = await _api.getMe();
      user = FutBoliaUser.fromJson(me);
      await _storage.write(key: _kUser, value: jsonEncode(me));
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        final ok = await _silentRefresh();
        if (!ok) rethrow;
        return;
      }
      rethrow;
    }
  }

  /// Returns true if a new access token was obtained.
  Future<bool> _silentRefresh() async {
    final refresh = await _storage.read(key: _kRefresh);
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final data = await _api.refresh(refresh);
      await _persistSession(data);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return false;
      }
      // Transient API error — do not wipe session.
      return false;
    } catch (_) {
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
    required String email,
    required String password,
  }) async {
    errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.login(
        email: email.trim(),
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
    SocketService.instance.disconnect();
    await _clearTokens();
    user = null;
    pendingEmailVerificationToken = null;
    notifyListeners();
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access == null || refresh == null) {
      throw ApiException('Réponse d’authentification incomplète');
    }
    final rawUser = data['user'];
    if (rawUser is! Map) {
      throw ApiException('Réponse utilisateur invalide');
    }
    final userMap = Map<String, dynamic>.from(rawUser);
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    await _storage.write(key: _kUser, value: jsonEncode(userMap));
    _api.setAccessToken(access);
    user = FutBoliaUser.fromJson(userMap);
    await _startRealtime();
  }

  Future<void> _startRealtime() async {
    SocketService.instance.connect(_api.accessToken);
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
