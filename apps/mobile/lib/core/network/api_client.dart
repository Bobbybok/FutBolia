import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../i18n/fr_labels.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _accessToken;

  void setAccessToken(String? token) => _accessToken = token;

  Future<Map<String, dynamic>> getHealth() {
    return _get('/health');
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String pseudo,
  }) {
    return _post('/auth/register', {
      'email': email,
      'password': password,
      'pseudo': pseudo,
    });
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _post('/auth/login', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> verifyEmail(String token) {
    return _post('/auth/verify-email', {'token': token});
  }

  Future<Map<String, dynamic>> forgotPassword(String email) {
    return _post('/auth/forgot-password', {'email': email});
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) {
    return _post('/auth/reset-password', {
      'token': token,
      'newPassword': newPassword,
    });
  }

  Future<void> logout(String refreshToken) async {
    await _post('/auth/logout', {'refreshToken': refreshToken});
  }

  Future<Map<String, dynamic>> getMe() => _get('/users/me', auth: true);

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> body) {
    return _patch('/users/me', body, auth: true);
  }

  Future<List<Map<String, dynamic>>> listTournaments({
    String? query,
    bool mine = false,
  }) async {
    final params = <String, String>{};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (mine) params['mine'] = 'true';
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/tournaments').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final response = await _client
        .get(uri, headers: _headers(auth: true))
        .timeout(const Duration(seconds: 10));
    final decoded = _decodeDynamic(response);
    if (decoded is! List) {
      throw ApiException('Réponse tournois invalide');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> getTournament(String id) {
    return _get('/tournaments/$id', auth: true);
  }

  Future<List<Map<String, dynamic>>> getTournamentMembers(String id) async {
    final decoded = await _getDynamic('/tournaments/$id/members', auth: true);
    if (decoded is! List) {
      throw ApiException('Réponse membres invalide');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createTournament(Map<String, dynamic> body) {
    return _post('/tournaments', body, auth: true);
  }

  Future<Map<String, dynamic>> deleteTournament(String id) async {
    final response = await _client
        .delete(
          _uri('/tournaments/$id'),
          headers: _headers(auth: true),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = _decodeDynamic(response);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'success': true};
  }

  Future<Map<String, dynamic>> joinTournament(String id, {String? code}) {
    return _post('/tournaments/$id/join', {
      if (code != null && code.isNotEmpty) 'code': code,
    }, auth: true);
  }

  Future<List<Map<String, dynamic>>> listTeams(String tournamentId) async {
    final decoded = await _getDynamic(
      '/tournaments/$tournamentId/teams',
      auth: true,
    );
    if (decoded is! List) {
      throw ApiException('Réponse équipes invalide');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createTeam(
    String tournamentId,
    Map<String, dynamic> body,
  ) {
    return _post('/tournaments/$tournamentId/teams', body, auth: true);
  }

  Future<Map<String, dynamic>> getTeam(String teamId) {
    return _get('/teams/$teamId', auth: true);
  }

  Future<Map<String, dynamic>> addTeamMember(
    String teamId,
    Map<String, dynamic> body,
  ) {
    return _post('/teams/$teamId/members', body, auth: true);
  }

  Future<Map<String, dynamic>> updateTeamMember(
    String teamId,
    String userId,
    Map<String, dynamic> body,
  ) {
    return _patch('/teams/$teamId/members/$userId', body, auth: true);
  }

  Future<Map<String, dynamic>> removeTeamMember(
    String teamId,
    String userId,
  ) async {
    final response = await _client
        .delete(
          _uri('/teams/$teamId/members/$userId'),
          headers: _headers(auth: true),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = _decodeDynamic(response);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> setTeamCaptain(String teamId, String userId) {
    return _post('/teams/$teamId/captain', {'userId': userId}, auth: true);
  }

  Future<Map<String, dynamic>> leaveTeam(String teamId) {
    return _post('/teams/$teamId/leave', {}, auth: true);
  }

  Future<Map<String, dynamic>> validateTeam(String teamId) {
    return _post('/teams/$teamId/validate', {}, auth: true);
  }

  Future<List<Map<String, dynamic>>> getMercato(String tournamentId) async {
    final decoded = await _getDynamic(
      '/tournaments/$tournamentId/mercato',
      auth: true,
    );
    if (decoded is! List) {
      throw ApiException('Réponse mercato invalide');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMyOffers({String? tournamentId}) async {
    final params = <String, String>{};
    if (tournamentId != null) params['tournamentId'] = tournamentId;
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/mercato/offers/mine').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final response = await _client
        .get(uri, headers: _headers(auth: true))
        .timeout(const Duration(seconds: 10));
    final decoded = _decodeDynamic(response);
    if (decoded is! List) {
      throw ApiException('Réponse offres invalide');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createOffer(Map<String, dynamic> body) {
    return _post('/mercato/offers', body, auth: true);
  }

  Future<Map<String, dynamic>> acceptOffer(String offerId) {
    return _post('/mercato/offers/$offerId/accept', {}, auth: true);
  }

  Future<Map<String, dynamic>> rejectOffer(String offerId) {
    return _post('/mercato/offers/$offerId/reject', {}, auth: true);
  }

  Future<Map<String, dynamic>> nominateSelector(
    String tournamentId,
    String userId,
  ) {
    return _post('/tournaments/$tournamentId/selectors', {
      'userId': userId,
    }, auth: true);
  }

  Future<Map<String, dynamic>> assignTeamSelector(
    String teamId,
    String selectorId,
  ) {
    return _post('/teams/$teamId/selector', {
      'selectorId': selectorId,
    }, auth: true);
  }

  Future<List<Map<String, dynamic>>> listMatches(String tournamentId) async {
    final decoded = await _getDynamic(
      '/tournaments/$tournamentId/matches',
      auth: true,
    );
    if (decoded is! List) {
      throw ApiException('Réponse matchs invalide');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getStandings(String tournamentId) async {
    final decoded = await _getDynamic(
      '/tournaments/$tournamentId/standings',
      auth: true,
    );
    if (decoded is! List) {
      throw ApiException('Réponse classement invalide');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createMatch(
    String tournamentId,
    Map<String, dynamic> body,
  ) {
    return _post('/tournaments/$tournamentId/matches', body, auth: true);
  }

  Future<Map<String, dynamic>> generateRoundRobin(String tournamentId) {
    return _post(
      '/tournaments/$tournamentId/matches/generate-round-robin',
      {},
      auth: true,
    );
  }

  Future<Map<String, dynamic>> updateMatch(
    String matchId,
    Map<String, dynamic> body,
  ) {
    return _patch('/matches/$matchId', body, auth: true);
  }

  Future<Map<String, dynamic>> cancelMatch(String matchId) {
    return _post('/matches/$matchId/cancel', {}, auth: true);
  }

  Future<Map<String, dynamic>> deleteMatch(String matchId) async {
    final response = await _client
        .delete(
          _uri('/matches/$matchId'),
          headers: _headers(auth: true),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = _decodeDynamic(response);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'success': true};
  }

  Future<List<Map<String, dynamic>>> listChatMessages(
    String tournamentId, {
    String? before,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (before != null) params['before'] = before;
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/tournaments/$tournamentId/chat')
        .replace(queryParameters: params);
    final response = await _client
        .get(uri, headers: _headers(auth: true))
        .timeout(const Duration(seconds: 10));
    final decoded = _decodeDynamic(response);
    if (decoded is! List) {
      throw ApiException('Réponse chat invalide');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> postChatMessage(
    String tournamentId,
    String body,
  ) {
    return _post('/tournaments/$tournamentId/chat', {'body': body}, auth: true);
  }

  Future<Map<String, dynamic>> deleteChatMessage(String messageId) async {
    final response = await _client
        .delete(
          _uri('/chat/messages/$messageId'),
          headers: _headers(auth: true),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = _decodeDynamic(response);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'success': true};
  }

  Future<Map<String, dynamic>> _get(String path, {bool auth = false}) async {
    final decoded = await _getDynamic(path, auth: auth);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw ApiException('Réponse invalide');
  }

  Future<dynamic> _getDynamic(String path, {bool auth = false}) async {
    final response = await _client
        .get(_uri(path), headers: _headers(auth: auth))
        .timeout(const Duration(seconds: 10));
    return _decodeDynamic(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final response = await _client
        .post(
          _uri(path),
          headers: _headers(auth: auth),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = _decodeDynamic(response);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final response = await _client
        .patch(
          _uri(path),
          headers: _headers(auth: auth),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = _decodeDynamic(response);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Map<String, String> _headers({required bool auth}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  dynamic _decodeDynamic(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      decoded = jsonDecode(response.body);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Erreur serveur (${response.statusCode})';
      if (decoded is Map) {
        final raw = decoded['message'];
        if (raw is List) {
          message = raw.map((e) => FrLabels.apiMessage(e.toString())).join(', ');
        } else if (raw != null) {
          message = FrLabels.apiMessage(raw.toString());
        }
      }
      throw ApiException(message, statusCode: response.statusCode);
    }
    return decoded;
  }

  void dispose() => _client.close();
}
