import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../domain/futbolia_user.dart';

class AuthSession extends ChangeNotifier {
  AuthSession({
    ApiClient? apiClient,
    FlutterSecureStorage? storage,
  })  : _api = apiClient ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage();

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  ApiClient get api => _api;

  FutBoliaUser? user;
  bool bootstrapping = true;
  String? errorMessage;
  String? pendingEmailVerificationToken;

  bool get isAuthenticated => user != null;

  Future<void> bootstrap() async {
    bootstrapping = true;
    notifyListeners();
    try {
      final access = await _storage.read(key: 'accessToken');
      if (access == null) {
        user = null;
        return;
      }
      _api.setAccessToken(access);
      final me = await _api.getMe();
      user = FutBoliaUser.fromJson(me);
    } catch (_) {
      await _clearTokens();
      user = null;
    } finally {
      bootstrapping = false;
      notifyListeners();
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
    } on ApiException catch (e) {
      errorMessage = e.message;
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
      pendingEmailVerificationToken = null;
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
    } on ApiException catch (e) {
      errorMessage = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final refresh = await _storage.read(key: 'refreshToken');
    try {
      if (refresh != null) {
        await _api.logout(refresh);
      }
    } catch (_) {
      // Local logout still proceeds.
    }
    await _clearTokens();
    user = null;
    pendingEmailVerificationToken = null;
    notifyListeners();
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String;
    final refresh = data['refreshToken'] as String;
    await _storage.write(key: 'accessToken', value: access);
    await _storage.write(key: 'refreshToken', value: refresh);
    _api.setAccessToken(access);
    user = FutBoliaUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> _clearTokens() async {
    _api.setAccessToken(null);
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
  }
}
