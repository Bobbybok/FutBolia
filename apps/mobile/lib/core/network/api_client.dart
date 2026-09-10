import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
  Future<bool>? _refreshFuture;

  /// Called once on HTTP 401 for authenticated requests. Return true if a new
  /// access token was stored and the request should be retried.
  Future<bool> Function()? onUnauthorized;

  String? get accessToken => _accessToken;

  /// Called whenever the access token is set or cleared.
  void Function(String? token)? onAccessTokenChanged;

  void setAccessToken(String? token) {
    _accessToken = token;
    onAccessTokenChanged?.call(token);
  }

  Future<Map<String, dynamic>> getHealth({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final response = await _client
          .get(_uri('/health'), headers: _headers(auth: false))
          .timeout(timeout);
      final decoded = _decodeDynamic(response);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw ApiException('Réponse invalide');
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Délai dépassé. Vérifie que l’API tourne (${AppConfig.apiBaseUrl}).',
        statusCode: 504,
      );
    } on SocketException {
      throw ApiException(
        'Impossible de joindre le serveur (${AppConfig.apiBaseUrl}).',
        statusCode: 503,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Connexion impossible: ${e.message}. URL: ${AppConfig.apiBaseUrl}',
        statusCode: 503,
      );
    }
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
    String? email,
    String? pseudo,
    required String password,
  }) {
    return _post('/auth/login', {
      if (email != null && email.isNotEmpty) 'email': email,
      if (pseudo != null && pseudo.isNotEmpty) 'pseudo': pseudo,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> verifyEmail(String token) {
    return _post('/auth/verify-email', {'token': token.trim()});
  }

  Future<Map<String, dynamic>> resendVerification() {
    return _post('/auth/resend-verification', {}, auth: true);
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

  /// Exchange refresh token for a new access + refresh pair.
  Future<Map<String, dynamic>> refresh(String refreshToken) {
    return _post(
      '/auth/refresh',
      {'refreshToken': refreshToken},
      timeout: const Duration(seconds: 60),
    );
  }

  Future<Map<String, dynamic>> getMe() => _get('/users/me', auth: true);

  Future<List<Map<String, dynamic>>> adminListAdmins() async {
    return _getList('/admin/admins');
  }

  Future<List<Map<String, dynamic>>> adminSearchUsers(String query) async {
    final q = query.trim();
    final path = q.isEmpty
        ? '/admin/users'
        : '/admin/users?q=${Uri.encodeQueryComponent(q)}';
    return _getList(path);
  }

  Future<Map<String, dynamic>> adminGrant({
    required String userId,
    required List<String> permissions,
  }) {
    return _post('/admin/admins/$userId/grant', {'permissions': permissions}, auth: true);
  }

  Future<Map<String, dynamic>> adminUpdatePermissions({
    required String userId,
    required List<String> permissions,
  }) {
    return _patch('/admin/admins/$userId/permissions', {
      'permissions': permissions,
    }, auth: true);
  }

  Future<Map<String, dynamic>> adminRevoke(String userId) {
    return _delete('/admin/admins/$userId/revoke');
  }

  Future<List<Map<String, dynamic>>> adminListModerators() {
    return _getList('/admin/moderators');
  }

  Future<Map<String, dynamic>> adminGrantModerator({
    required String userId,
    required List<String> permissions,
  }) {
    return _post('/admin/moderators/$userId/grant', {
      'permissions': permissions,
    }, auth: true);
  }

  Future<Map<String, dynamic>> adminUpdateModeratorPermissions({
    required String userId,
    required List<String> permissions,
  }) {
    return _patch('/admin/moderators/$userId/permissions', {
      'permissions': permissions,
    }, auth: true);
  }

  Future<Map<String, dynamic>> adminRevokeModerator(String userId) {
    return _delete('/admin/moderators/$userId/revoke');
  }

  Future<Map<String, dynamic>> adminGetUser(String id) {
    return _get('/admin/users/$id', auth: true);
  }

  Future<Map<String, dynamic>> adminBanUser(String id, {String? reason}) {
    return _post('/admin/users/$id/ban', {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    }, auth: true);
  }

  Future<Map<String, dynamic>> adminUnbanUser(String id) {
    return _post('/admin/users/$id/unban', {}, auth: true);
  }

  Future<Map<String, dynamic>> adminForceVerify(String id) {
    return _post('/admin/users/$id/verify-email', {}, auth: true);
  }

  Future<Map<String, dynamic>> adminForceReset(String id) {
    return _post('/admin/users/$id/reset-password', {}, auth: true);
  }

  Future<Map<String, dynamic>> adminRevokeSessions(String id) {
    return _post('/admin/users/$id/revoke-sessions', {}, auth: true);
  }

  Future<Map<String, dynamic>> adminPatchUser(
    String id,
    Map<String, dynamic> body,
  ) {
    return _patch('/admin/users/$id', body, auth: true);
  }

  Future<Map<String, dynamic>> adminDeleteUser(String id) {
    return _delete('/admin/users/$id');
  }

  Future<List<Map<String, dynamic>>> adminListTournaments() {
    return _getList('/admin/tournaments');
  }

  Future<Map<String, dynamic>> adminPatchTournament(
    String id,
    Map<String, dynamic> body,
  ) {
    return _patch('/admin/tournaments/$id', body, auth: true);
  }

  Future<Map<String, dynamic>> adminDeleteTournament(String id) {
    return _delete('/admin/tournaments/$id');
  }

  Future<Map<String, dynamic>> adminTransferOwner({
    required String tournamentId,
    required String userId,
  }) {
    return _post('/admin/tournaments/$tournamentId/transfer', {
      'userId': userId,
    }, auth: true);
  }

  Future<List<Map<String, dynamic>>> adminListTournamentTeams(String id) {
    return _getList('/admin/tournaments/$id/teams');
  }

  Future<List<Map<String, dynamic>>> adminListTournamentMatches(String id) {
    return _getList('/admin/tournaments/$id/matches');
  }

  Future<Map<String, dynamic>> adminForceTeamStatus({
    required String teamId,
    required String status,
  }) {
    return _post('/admin/teams/$teamId/status', {'status': status}, auth: true);
  }

  Future<Map<String, dynamic>> adminPatchTeam(
    String teamId,
    Map<String, dynamic> body,
  ) {
    return _patch('/admin/teams/$teamId', body, auth: true);
  }

  Future<Map<String, dynamic>> adminDeleteTeam(String teamId) {
    return _delete('/admin/teams/$teamId');
  }

  Future<Map<String, dynamic>> adminPatchMatch(
    String matchId,
    Map<String, dynamic> body,
  ) {
    return _patch('/admin/matches/$matchId', body, auth: true);
  }

  Future<Map<String, dynamic>> adminDeleteMatch(String matchId) {
    return _delete('/admin/matches/$matchId');
  }

  Future<List<Map<String, dynamic>>> adminListPickupMatches() {
    return _getList('/admin/pickup-matches');
  }

  Future<Map<String, dynamic>> adminPatchPickup(
    String id,
    Map<String, dynamic> body,
  ) {
    return _patch('/admin/pickup-matches/$id', body, auth: true);
  }

  Future<Map<String, dynamic>> adminDeletePickup(String id) {
    return _delete('/admin/pickup-matches/$id');
  }

  Future<Map<String, dynamic>> adminCancelMatch(String matchId) {
    return _post('/admin/matches/$matchId/cancel', {}, auth: true);
  }

  Future<List<Map<String, dynamic>>> adminListReports() {
    return _getList('/admin/reports');
  }

  Future<Map<String, dynamic>> adminResolveReport({
    required String id,
    required String status,
    String? action,
    int? timeoutMinutes,
    bool deleteMessage = false,
  }) {
    return _patch('/admin/reports/$id', {
      'status': status,
      'action': ?action,
      'timeoutMinutes': ?timeoutMinutes,
      if (deleteMessage) 'deleteMessage': true,
    }, auth: true);
  }

  Future<Map<String, dynamic>> adminDeleteReport(String id) {
    return _delete('/admin/reports/$id');
  }

  Future<List<Map<String, dynamic>>> adminListDeletedMessages() {
    return _getList('/admin/messages');
  }

  Future<Map<String, dynamic>> listReportReasons() {
    return _get('/reports/reasons', auth: true);
  }

  Future<Map<String, dynamic>> createReport({
    required String type,
    required String targetId,
    required String reasonCode,
    String? comment,
  }) {
    return _post('/reports', {
      'type': type,
      'targetId': targetId,
      'reasonCode': reasonCode,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    }, auth: true);
  }

  Future<Map<String, dynamic>> getPublicUser(String id) {
    return _get('/users/$id', auth: true);
  }

  Future<Map<String, dynamic>> hideCareerItem({
    required String itemType,
    required String itemId,
    required bool hidden,
  }) {
    return _patch('/users/me/hidden', {
      'itemType': itemType,
      'itemId': itemId,
      'hidden': hidden,
    }, auth: true);
  }

  Future<Map<String, dynamic>> removeCareerItem({
    required String userId,
    required String itemType,
    required String itemId,
  }) {
    return _delete('/users/$userId/career/$itemType/$itemId');
  }

  Future<Map<String, dynamic>> uploadMyAvatar({
    required List<int> bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) {
    return _uploadMultipart(
      '/users/me/avatar',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
  }

  Future<Map<String, dynamic>> uploadTournamentCover({
    required String tournamentId,
    required List<int> bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) {
    return _uploadMultipart(
      '/tournaments/$tournamentId/cover',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
  }

  Future<Map<String, dynamic>> deleteTournamentCover(String tournamentId) {
    return _delete('/tournaments/$tournamentId/cover');
  }

  Future<List<Map<String, dynamic>>> listTournamentPhotos(
    String tournamentId,
  ) async {
    final decoded =
        await _getDynamic('/tournaments/$tournamentId/photos', auth: true);
    if (decoded is! List) {
      throw ApiException('Réponse album invalide');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> uploadTournamentPhoto({
    required String tournamentId,
    required List<int> bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) {
    return _uploadMultipart(
      '/tournaments/$tournamentId/photos',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
  }

  Future<Map<String, dynamic>> deleteTournamentPhoto({
    required String tournamentId,
    required String photoId,
  }) {
    return _delete('/tournaments/$tournamentId/photos/$photoId');
  }

  Future<Map<String, dynamic>> _uploadMultipart(
    String path, {
    required List<int> bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) {
    return _withAuthRetry(true, () async {
      try {
        final request = http.MultipartRequest('POST', _uri(path));
        final headers = _headers(auth: true);
        headers.remove('Content-Type');
        request.headers.addAll(headers);
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
            contentType: MediaType.parse(contentType),
          ),
        );
        final streamed = await request.send().timeout(
          const Duration(seconds: 45),
        );
        final response = await http.Response.fromStream(streamed);
        final decoded = _decodeDynamic(response);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return <String, dynamic>{};
      } on ApiException {
        rethrow;
      } on TimeoutException {
        throw ApiException('Délai dépassé. Réessaie.');
      } on SocketException {
        throw ApiException(
          'Impossible de joindre le serveur (${AppConfig.apiBaseUrl}).',
        );
      } on http.ClientException catch (e) {
        throw ApiException('Connexion impossible: ${e.message}');
      }
    });
  }

  Future<Map<String, dynamic>> adminDeleteMessage(String id) {
    return _delete('/admin/messages/$id');
  }

  Future<Map<String, dynamic>> adminStats() {
    return _get('/admin/stats', auth: true);
  }

  Future<Map<String, dynamic>> adminSecurity() {
    return _get('/admin/security', auth: true);
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    return _withAuthRetry(true, () async {
      try {
        final decoded = await _getDynamic(path, auth: true);
        return _asMapList(decoded);
      } on ApiException {
        rethrow;
      } on TimeoutException {
        throw ApiException(
          'Délai dépassé. Vérifie que l’API tourne (${AppConfig.apiBaseUrl}).',
        );
      } on SocketException {
        throw ApiException(
          'Impossible de joindre le serveur (${AppConfig.apiBaseUrl}).',
        );
      } on http.ClientException catch (e) {
        throw ApiException(
          'Connexion impossible: ${e.message}. URL: ${AppConfig.apiBaseUrl}',
        );
      } catch (_) {
        throw ApiException('Chargement impossible');
      }
    });
  }

  List<Map<String, dynamic>> _asMapList(dynamic decoded) {
    if (decoded is! List) {
      throw ApiException('Réponse liste invalide');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

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

  Future<Map<String, dynamic>> updateTournament(
    String id,
    Map<String, dynamic> body,
  ) {
    return _patch('/tournaments/$id', body, auth: true);
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

  Future<List<Map<String, dynamic>>> listPickupMatches({bool mine = false}) async {
    final params = <String, String>{};
    if (mine) params['mine'] = 'true';
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/pickup-matches').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final response = await _client
        .get(uri, headers: _headers(auth: true))
        .timeout(const Duration(seconds: 10));
    final decoded = _decodeDynamic(response);
    if (decoded is! List) {
      throw ApiException('Réponse matchs invalide');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> getPickupMatch(String id) {
    return _get('/pickup-matches/$id', auth: true);
  }

  Future<Map<String, dynamic>> createPickupMatch(Map<String, dynamic> body) {
    return _post('/pickup-matches', body, auth: true);
  }

  Future<Map<String, dynamic>> joinPickupMatch(String id, {String? code}) {
    return _post('/pickup-matches/$id/join', {
      if (code != null && code.isNotEmpty) 'code': code,
    }, auth: true);
  }

  Future<Map<String, dynamic>> leavePickupMatch(String id) {
    return _post('/pickup-matches/$id/leave', {}, auth: true);
  }

  Future<Map<String, dynamic>> addPickupMember(
    String matchId,
    Map<String, dynamic> body,
  ) {
    return _post('/pickup-matches/$matchId/members', body, auth: true);
  }

  Future<Map<String, dynamic>> updatePickupMemberSide(
    String matchId,
    String userId,
    String? side,
  ) {
    return _patch('/pickup-matches/$matchId/members/$userId', {
      'side': side,
    }, auth: true);
  }

  Future<void> kickPickupMember(String matchId, String userId) async {
    await _delete('/pickup-matches/$matchId/members/$userId');
  }

  Future<Map<String, dynamic>> scorePickupMatch(
    String id,
    Map<String, dynamic> body,
  ) {
    return _patch('/pickup-matches/$id/score', body, auth: true);
  }

  Future<Map<String, dynamic>> cancelPickupMatch(String id) {
    return _post('/pickup-matches/$id/cancel', {}, auth: true);
  }

  Future<Map<String, dynamic>> deletePickupMatch(String id) {
    return _delete('/pickup-matches/$id');
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

  Future<Map<String, dynamic>> updateTeam(
    String teamId,
    Map<String, dynamic> body,
  ) {
    return _patch('/teams/$teamId', body, auth: true);
  }

  Future<Map<String, dynamic>> deleteTeam(String teamId) {
    return _delete('/teams/$teamId');
  }

  Future<Map<String, dynamic>> assignTournamentTeam(
    String tournamentId,
    Map<String, dynamic> body,
  ) {
    return _post('/tournaments/$tournamentId/assign-team', body, auth: true);
  }

  Future<void> addTournamentMember(String tournamentId, String userId) async {
    await _post('/tournaments/$tournamentId/members', {
      'userId': userId,
    }, auth: true);
  }

  Future<void> kickTournamentMember(
    String tournamentId,
    String userId,
  ) async {
    await _delete('/tournaments/$tournamentId/members/$userId');
  }

  Future<Map<String, dynamic>> leaveTournament(String tournamentId) {
    return _post('/tournaments/$tournamentId/leave', {}, auth: true);
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
    bool restoreInbox = false,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (before != null) params['before'] = before;
    if (restoreInbox) params['restoreInbox'] = '1';
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

  Future<List<Map<String, dynamic>>> listTournamentChats() {
    return _getList('/chat/inbox');
  }

  Future<int> tournamentChatUnreadCount() async {
    final data = await _get('/chat/unread-count', auth: true);
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> listFriends() {
    return _getList('/friends');
  }

  Future<List<Map<String, dynamic>>> listEventInvites() {
    return _getList('/invites');
  }

  Future<Map<String, dynamic>> createEventInvites({
    required String targetType,
    required String targetId,
    List<String> friendIds = const [],
    List<String> userIds = const [],
    List<String> pseudos = const [],
  }) {
    return _post('/invites', {
      'targetType': targetType,
      'targetId': targetId,
      if (friendIds.isNotEmpty) 'friendIds': friendIds,
      if (userIds.isNotEmpty) 'userIds': userIds,
      if (pseudos.isNotEmpty) 'pseudos': pseudos,
    }, auth: true);
  }

  Future<Map<String, dynamic>> acceptEventInvite(String id) {
    return _post('/invites/$id/accept', {}, auth: true);
  }

  Future<Map<String, dynamic>> declineEventInvite(String id) {
    return _post('/invites/$id/decline', {}, auth: true);
  }

  Future<Map<String, dynamic>> listFriendRequests() {
    return _get('/friends/requests', auth: true);
  }

  Future<List<Map<String, dynamic>>> searchPlayers(String query) {
    return _getList(
      '/friends/search?q=${Uri.encodeQueryComponent(query.trim())}',
    );
  }

  Future<Map<String, dynamic>> sendFriendRequest({
    String? userId,
    String? pseudo,
  }) {
    return _post('/friends/requests', {
      if (userId != null) 'userId': userId,
      if (pseudo != null && pseudo.isNotEmpty) 'pseudo': pseudo,
    }, auth: true);
  }

  Future<Map<String, dynamic>> acceptFriendRequest(String id) {
    return _post('/friends/requests/$id/accept', {}, auth: true);
  }

  Future<Map<String, dynamic>> declineFriendRequest(String id) {
    return _post('/friends/requests/$id/decline', {}, auth: true);
  }

  Future<Map<String, dynamic>> unfriend(String userId) {
    return _delete('/friends/$userId');
  }

  Future<List<Map<String, dynamic>>> listConversations() {
    return _getList('/conversations');
  }

  Future<int> conversationsUnreadCount() async {
    final data = await _get('/conversations/unread-count', auth: true);
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> openConversation(String friendId) {
    return _post('/conversations', {'friendId': friendId}, auth: true);
  }

  Future<Map<String, dynamic>> listDirectMessages(
    String conversationId, {
    String? before,
    int limit = 50,
  }) {
    final path = before == null
        ? '/conversations/$conversationId/messages?limit=$limit'
        : '/conversations/$conversationId/messages?limit=$limit&before=$before';
    return _get(path, auth: true);
  }

  Future<Map<String, dynamic>> postDirectMessage(
    String conversationId,
    String body,
  ) {
    return _post(
      '/conversations/$conversationId/messages',
      {'body': body},
      auth: true,
    );
  }

  Future<Map<String, dynamic>> deleteDirectMessage(
    String conversationId,
    String messageId,
  ) {
    return _delete('/conversations/$conversationId/messages/$messageId');
  }

  Future<Map<String, dynamic>> markConversationRead(String conversationId) {
    return _patch('/conversations/$conversationId/read', {}, auth: true);
  }

  Future<Map<String, dynamic>> clearConversation(String conversationId) {
    return _post('/conversations/$conversationId/clear', {}, auth: true);
  }

  Future<Map<String, dynamic>> hideConversation(String conversationId) {
    return _delete('/conversations/$conversationId');
  }

  Future<Map<String, dynamic>> clearTournamentChat(String tournamentId) {
    return _post('/tournaments/$tournamentId/chat/clear', {}, auth: true);
  }

  Future<Map<String, dynamic>> clearTournamentChatForEveryone(
    String tournamentId,
  ) {
    return _post('/tournaments/$tournamentId/chat/clear-all', {}, auth: true);
  }

  Future<Map<String, dynamic>> hideTournamentChat(String tournamentId) {
    return _post('/tournaments/$tournamentId/chat/hide', {}, auth: true);
  }

  Future<List<Map<String, dynamic>>> listTeamChatMessages(
    String teamId, {
    String? before,
    int limit = 50,
    bool restoreInbox = false,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (before != null) params['before'] = before;
    if (restoreInbox) params['restoreInbox'] = '1';
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/teams/$teamId/chat')
        .replace(queryParameters: params);
    final response = await _client
        .get(uri, headers: _headers(auth: true))
        .timeout(const Duration(seconds: 10));
    final decoded = _decodeDynamic(response);
    final list = decoded is Map ? decoded['messages'] : decoded;
    if (list is! List) {
      throw ApiException('Réponse chat équipe invalide');
    }
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> postTeamChatMessage(
    String teamId,
    String body,
  ) {
    return _post('/teams/$teamId/chat', {'body': body}, auth: true);
  }

  Future<Map<String, dynamic>> deleteTeamChatMessage(String messageId) async {
    return _delete('/chat/team-messages/$messageId');
  }

  Future<Map<String, dynamic>> clearTeamChat(String teamId) {
    return _post('/teams/$teamId/chat/clear', {}, auth: true);
  }

  Future<Map<String, dynamic>> clearTeamChatForEveryone(String teamId) {
    return _post('/teams/$teamId/chat/clear-all', {}, auth: true);
  }

  Future<Map<String, dynamic>> hideTeamChat(String teamId) {
    return _post('/teams/$teamId/chat/hide', {}, auth: true);
  }

  Future<Map<String, dynamic>> toggleTeamMemberSlot(
    String teamId,
    String userId,
  ) {
    return _post(
      '/teams/$teamId/members/$userId/toggle-slot',
      {},
      auth: true,
    );
  }

  Future<List<Map<String, dynamic>>> listInterTeamChatMessages(
    String tournamentId, {
    String? before,
    int limit = 50,
    bool restoreInbox = false,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (before != null) params['before'] = before;
    if (restoreInbox) params['restoreInbox'] = '1';
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/tournaments/$tournamentId/inter-team-chat',
    ).replace(queryParameters: params);
    final response = await _client
        .get(uri, headers: _headers(auth: true))
        .timeout(const Duration(seconds: 10));
    final decoded = _decodeDynamic(response);
    final list = decoded is Map ? decoded['messages'] : decoded;
    if (list is! List) {
      throw ApiException('Réponse chat inter-équipes invalide');
    }
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> postInterTeamChatMessage(
    String tournamentId,
    String body,
  ) {
    return _post(
      '/tournaments/$tournamentId/inter-team-chat',
      {'body': body},
      auth: true,
    );
  }

  Future<Map<String, dynamic>> deleteInterTeamChatMessage(String messageId) {
    return _delete('/chat/inter-team-messages/$messageId');
  }

  Future<Map<String, dynamic>> clearInterTeamChat(String tournamentId) {
    return _post(
      '/tournaments/$tournamentId/inter-team-chat/clear',
      {},
      auth: true,
    );
  }

  Future<Map<String, dynamic>> clearInterTeamChatForEveryone(
    String tournamentId,
  ) {
    return _post(
      '/tournaments/$tournamentId/inter-team-chat/clear-all',
      {},
      auth: true,
    );
  }

  Future<Map<String, dynamic>> hideInterTeamChat(String tournamentId) {
    return _post(
      '/tournaments/$tournamentId/inter-team-chat/hide',
      {},
      auth: true,
    );
  }

  Future<Map<String, dynamic>> upsertDeviceToken({
    required String token,
    required String platform,
  }) {
    return _post('/users/me/device-token', {
      'token': token,
      'platform': platform,
    }, auth: true);
  }

  Future<Map<String, dynamic>> deleteDeviceToken(String token) {
    return _delete('/users/me/device-token', body: {'token': token});
  }

  Future<Map<String, dynamic>> _get(String path, {bool auth = false}) async {
    return _withAuthRetry(auth, () async {
      try {
        final decoded = await _getDynamic(path, auth: auth);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        throw ApiException('Réponse invalide');
      } on ApiException {
        rethrow;
      } on TimeoutException {
        throw ApiException(
          'Délai dépassé. Vérifie que l’API tourne (${AppConfig.apiBaseUrl}).',
        );
      } on SocketException {
        throw ApiException(
          'Impossible de joindre le serveur (${AppConfig.apiBaseUrl}). '
          'Même Wi‑Fi ? API démarrée ?',
        );
      } on http.ClientException catch (e) {
        throw ApiException(
          'Connexion impossible: ${e.message}. URL: ${AppConfig.apiBaseUrl}',
        );
      }
    });
  }

  Future<dynamic> _getDynamic(String path, {bool auth = false}) async {
    final response = await _client
        .get(_uri(path), headers: _headers(auth: auth))
        .timeout(const Duration(seconds: 20));
    return _decodeDynamic(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    return _withAuthRetry(auth, () async {
      try {
        final response = await _client
            .post(
              _uri(path),
              headers: _headers(auth: auth),
              body: jsonEncode(body),
            )
            .timeout(timeout);
        final decoded = _decodeDynamic(response);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return <String, dynamic>{};
      } on ApiException {
        rethrow;
      } on TimeoutException {
        throw ApiException(
          'Délai dépassé (base Neon en réveil ?). Réessaie dans quelques secondes.',
        );
      } on SocketException {
        throw ApiException(
          'Impossible de joindre le serveur (${AppConfig.apiBaseUrl}). '
          'Même Wi‑Fi ? API démarrée ?',
        );
      } on http.ClientException catch (e) {
        throw ApiException(
          'Connexion impossible: ${e.message}. URL: ${AppConfig.apiBaseUrl}',
        );
      }
    });
  }

  Future<Map<String, dynamic>> _delete(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _withAuthRetry(true, () async {
      try {
        final response = await _client
            .delete(
              _uri(path),
              headers: _headers(auth: true),
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
        final decoded = _decodeDynamic(response);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return <String, dynamic>{'success': true};
      } on ApiException {
        rethrow;
      } on TimeoutException {
        throw ApiException('Délai dépassé. Réessaie.');
      } on SocketException {
        throw ApiException(
          'Impossible de joindre le serveur (${AppConfig.apiBaseUrl}).',
        );
      } on http.ClientException catch (e) {
        throw ApiException('Connexion impossible: ${e.message}');
      }
    });
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    return _withAuthRetry(auth, () async {
      try {
        final response = await _client
            .patch(
              _uri(path),
              headers: _headers(auth: auth),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 30));
        final decoded = _decodeDynamic(response);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return <String, dynamic>{};
      } on ApiException {
        rethrow;
      } on TimeoutException {
        throw ApiException('Délai dépassé. Réessaie.');
      } on SocketException {
        throw ApiException(
          'Impossible de joindre le serveur (${AppConfig.apiBaseUrl}).',
        );
      } on http.ClientException catch (e) {
        throw ApiException('Connexion impossible: ${e.message}');
      }
    });
  }

  Future<T> _withAuthRetry<T>(
    bool auth,
    Future<T> Function() run,
  ) async {
    try {
      return await run();
    } on ApiException catch (e) {
      if (!auth || e.statusCode != 401 || onUnauthorized == null) {
        rethrow;
      }
      final ok = await _ensureFreshToken();
      if (!ok) rethrow;
      return await run();
    }
  }

  Future<bool> _ensureFreshToken() {
    final existing = _refreshFuture;
    if (existing != null) return existing;
    final future = () async {
      try {
        return await onUnauthorized!();
      } finally {
        _refreshFuture = null;
      }
    }();
    _refreshFuture = future;
    return future;
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
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
          response.statusCode >= 400
              ? 'Erreur serveur (${response.statusCode})'
              : 'Réponse invalide du serveur',
          statusCode: response.statusCode,
        );
      }
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
