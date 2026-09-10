import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

enum SocketConnectionState { disconnected, connecting, connected }

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  String? _token;
  bool _refreshing = false;
  final _joinedTournaments = <String>{};
  final _joinedTeams = <String>{};
  final _joinedInterTeams = <String>{};
  final _joinedPickups = <String>{};
  final _state = ValueNotifier<SocketConnectionState>(
    SocketConnectionState.disconnected,
  );

  final _tournamentMessage =
      StreamController<Map<String, dynamic>>.broadcast();
  final _tournamentMessageDeleted =
      StreamController<Map<String, dynamic>>.broadcast();
  final _tournamentChatCleared =
      StreamController<Map<String, dynamic>>.broadcast();
  final _teamMessage = StreamController<Map<String, dynamic>>.broadcast();
  final _teamMessageDeleted = StreamController<Map<String, dynamic>>.broadcast();
  final _teamChatCleared = StreamController<Map<String, dynamic>>.broadcast();
  final _interTeamMessage = StreamController<Map<String, dynamic>>.broadcast();
  final _interTeamMessageDeleted =
      StreamController<Map<String, dynamic>>.broadcast();
  final _interTeamChatCleared =
      StreamController<Map<String, dynamic>>.broadcast();
  final _privateMessage = StreamController<Map<String, dynamic>>.broadcast();
  final _privateMessageDeleted =
      StreamController<Map<String, dynamic>>.broadcast();
  final _friendRequest = StreamController<Map<String, dynamic>>.broadcast();
  final _friendAccepted = StreamController<Map<String, dynamic>>.broadcast();
  final _eventInvite = StreamController<Map<String, dynamic>>.broadcast();
  final _tournamentUpdated = StreamController<Map<String, dynamic>>.broadcast();
  final _pickupUpdated = StreamController<Map<String, dynamic>>.broadcast();
  final _lobbyChanged = StreamController<Map<String, dynamic>>.broadcast();

  final _inboxPing = StreamController<void>.broadcast();

  /// Latest access token (after refresh).
  String? Function()? tokenProvider;

  /// Refresh the JWT when the handshake is rejected.
  Future<bool> Function()? refreshAuth;

  ValueListenable<SocketConnectionState> get connectionState => _state;

  Stream<Map<String, dynamic>> get onTournamentMessage =>
      _tournamentMessage.stream;
  Stream<Map<String, dynamic>> get onTournamentMessageDeleted =>
      _tournamentMessageDeleted.stream;
  Stream<Map<String, dynamic>> get onTournamentChatCleared =>
      _tournamentChatCleared.stream;
  Stream<Map<String, dynamic>> get onTeamMessage => _teamMessage.stream;
  Stream<Map<String, dynamic>> get onTeamMessageDeleted =>
      _teamMessageDeleted.stream;
  Stream<Map<String, dynamic>> get onTeamChatCleared =>
      _teamChatCleared.stream;
  Stream<Map<String, dynamic>> get onInterTeamMessage =>
      _interTeamMessage.stream;
  Stream<Map<String, dynamic>> get onInterTeamMessageDeleted =>
      _interTeamMessageDeleted.stream;
  Stream<Map<String, dynamic>> get onInterTeamChatCleared =>
      _interTeamChatCleared.stream;
  Stream<Map<String, dynamic>> get onPrivateMessage => _privateMessage.stream;
  Stream<Map<String, dynamic>> get onPrivateMessageDeleted =>
      _privateMessageDeleted.stream;
  Stream<Map<String, dynamic>> get onFriendRequest => _friendRequest.stream;
  Stream<Map<String, dynamic>> get onFriendAccepted => _friendAccepted.stream;
  Stream<Map<String, dynamic>> get onEventInvite => _eventInvite.stream;
  Stream<Map<String, dynamic>> get onTournamentUpdated =>
      _tournamentUpdated.stream;
  Stream<Map<String, dynamic>> get onPickupUpdated => _pickupUpdated.stream;
  Stream<Map<String, dynamic>> get onLobbyChanged => _lobbyChanged.stream;
  Stream<void> get onInboxPing => _inboxPing.stream;

  void connect(String? token) {
    if (token == null || token.isEmpty) {
      disconnect();
      return;
    }
    _token = token;
    final existing = _socket;
    if (existing != null) {
      _applyAuth(existing, token);
      if (!existing.connected) {
        _state.value = SocketConnectionState.connecting;
        existing.connect();
      }
      return;
    }

    _state.value = SocketConnectionState.connecting;
    debugPrint('Socket.io → ${AppConfig.socketUrl}');
    final socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .setAuth({'token': token})
          .setQuery({'token': token})
          .enableForceNew()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      if (!identical(_socket, socket)) return;
      debugPrint('Socket.io connecté');
      _state.value = SocketConnectionState.connected;
      socket.emit('app:foreground');
      _rejoinTournaments();
      _rejoinTeams();
      _rejoinInterTeams();
      _rejoinPickups();
    });
    socket.onDisconnect((_) {
      if (!identical(_socket, socket)) return;
      debugPrint('Socket.io déconnecté');
      if (_token != null) {
        _state.value = SocketConnectionState.connecting;
      } else {
        _state.value = SocketConnectionState.disconnected;
      }
    });
    socket.onConnectError((err) {
      if (!identical(_socket, socket)) return;
      debugPrint('Socket.io connect_error: $err');
      _state.value = SocketConnectionState.connecting;
      unawaited(_recoverAuth());
    });
    socket.onError((err) {
      if (!identical(_socket, socket)) return;
      debugPrint('Socket.io error: $err');
    });
    socket.onReconnect((_) {
      if (!identical(_socket, socket)) return;
      _state.value = SocketConnectionState.connected;
      socket.emit('app:foreground');
      _rejoinTournaments();
      _rejoinTeams();
      _rejoinInterTeams();
      _rejoinPickups();
    });

    socket.on('tournament:message', (data) {
      final map = _asMap(data);
      if (map != null) {
        _tournamentMessage.add(map);
        _inboxPing.add(null);
      }
    });
    socket.on('tournament:messageDeleted', (data) {
      final map = _asMap(data);
      if (map != null) _tournamentMessageDeleted.add(map);
    });
    socket.on('tournament:chatCleared', (data) {
      final map = _asMap(data);
      if (map != null) _tournamentChatCleared.add(map);
    });
    socket.on('team:message', (data) {
      final map = _asMap(data);
      if (map != null) {
        _teamMessage.add(map);
        _inboxPing.add(null);
      }
    });
    socket.on('team:messageDeleted', (data) {
      final map = _asMap(data);
      if (map != null) _teamMessageDeleted.add(map);
    });
    socket.on('team:chatCleared', (data) {
      final map = _asMap(data);
      if (map != null) _teamChatCleared.add(map);
    });
    socket.on('interTeam:message', (data) {
      final map = _asMap(data);
      if (map != null) {
        _interTeamMessage.add(map);
        _inboxPing.add(null);
      }
    });
    socket.on('interTeam:messageDeleted', (data) {
      final map = _asMap(data);
      if (map != null) _interTeamMessageDeleted.add(map);
    });
    socket.on('interTeam:chatCleared', (data) {
      final map = _asMap(data);
      if (map != null) _interTeamChatCleared.add(map);
    });
    socket.on('private:message', (data) {
      final map = _asMap(data);
      if (map != null) {
        _privateMessage.add(map);
        _inboxPing.add(null);
      }
    });
    socket.on('private:messageDeleted', (data) {
      final map = _asMap(data);
      if (map != null) _privateMessageDeleted.add(map);
    });
    socket.on('friend:request', (data) {
      final map = _asMap(data);
      if (map != null) {
        _friendRequest.add(map);
        _inboxPing.add(null);
      }
    });
    socket.on('friend:accepted', (data) {
      final map = _asMap(data);
      if (map != null) {
        _friendAccepted.add(map);
        _inboxPing.add(null);
      }
    });
    socket.on('tournament:invite', (data) {
      final map = _asMap(data);
      if (map != null) {
        _eventInvite.add(map);
        _inboxPing.add(null);
      }
    });
    socket.on('pickup:invite', (data) {
      final map = _asMap(data);
      if (map != null) {
        _eventInvite.add(map);
        _inboxPing.add(null);
      }
    });
    socket.on('tournament:updated', (data) {
      final map = _asMap(data);
      if (map != null) _tournamentUpdated.add(map);
    });
    socket.on('pickup:updated', (data) {
      final map = _asMap(data);
      if (map != null) _pickupUpdated.add(map);
    });
    socket.on('lobby:changed', (data) {
      final map = _asMap(data);
      if (map != null) _lobbyChanged.add(map);
    });

    socket.connect();
  }

  /// Reconnect if we have a token but no live socket.
  void ensureConnected() {
    final token = tokenProvider?.call() ?? _token;
    if (token == null || token.isEmpty) return;
    final socket = _socket;
    if (socket == null) {
      connect(token);
      return;
    }
    _applyAuth(socket, token);
    if (!socket.connected) {
      _state.value = SocketConnectionState.connecting;
      socket.connect();
    }
  }

  /// Drop a stale engine and open a new one. Rooms are kept and re-joined.
  void recycle() {
    final token = tokenProvider?.call() ?? _token;
    final socket = _socket;
    _socket = null;
    try {
      socket?.disconnect();
      socket?.dispose();
    } catch (_) {}
    if (token != null && token.isNotEmpty) {
      connect(token);
    }
  }

  void updateToken(String? token) {
    _token = token;
    final socket = _socket;
    if (socket == null) {
      if (token != null && token.isNotEmpty) connect(token);
      return;
    }
    if (token == null || token.isEmpty) {
      disconnect();
      return;
    }
    _applyAuth(socket, token);
    if (!socket.connected) {
      _state.value = SocketConnectionState.connecting;
      socket.connect();
    }
  }

  void setForeground(bool foreground) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit(foreground ? 'app:foreground' : 'app:background');
  }

  void joinTournament(String tournamentId) {
    _joinedTournaments.add(tournamentId);
    _socket?.emit('joinTournament', {'tournamentId': tournamentId});
  }

  void leaveTournament(String tournamentId) {
    _joinedTournaments.remove(tournamentId);
    _socket?.emit('leaveTournament', {'tournamentId': tournamentId});
  }

  void joinTeam(String teamId) {
    _joinedTeams.add(teamId);
    _socket?.emit('joinTeam', {'teamId': teamId});
  }

  void leaveTeam(String teamId) {
    _joinedTeams.remove(teamId);
    _socket?.emit('leaveTeam', {'teamId': teamId});
  }

  void joinInterTeam(String tournamentId) {
    _joinedInterTeams.add(tournamentId);
    _socket?.emit('joinInterTeam', {'tournamentId': tournamentId});
  }

  void leaveInterTeam(String tournamentId) {
    _joinedInterTeams.remove(tournamentId);
    _socket?.emit('leaveInterTeam', {'tournamentId': tournamentId});
  }

  void joinPickup(String matchId) {
    _joinedPickups.add(matchId);
    _socket?.emit('joinPickup', {'matchId': matchId});
  }

  void leavePickup(String matchId) {
    _joinedPickups.remove(matchId);
    _socket?.emit('leavePickup', {'matchId': matchId});
  }

  void _rejoinTournaments() {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    for (final id in _joinedTournaments) {
      socket.emit('joinTournament', {'tournamentId': id});
    }
  }

  void _rejoinTeams() {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    for (final id in _joinedTeams) {
      socket.emit('joinTeam', {'teamId': id});
    }
  }

  void _rejoinInterTeams() {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    for (final id in _joinedInterTeams) {
      socket.emit('joinInterTeam', {'tournamentId': id});
    }
  }

  void _rejoinPickups() {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    for (final id in _joinedPickups) {
      socket.emit('joinPickup', {'matchId': id});
    }
  }

  void disconnect() {
    _token = null;
    _joinedTournaments.clear();
    _joinedTeams.clear();
    _joinedInterTeams.clear();
    _joinedPickups.clear();
    final socket = _socket;
    _socket = null;
    _state.value = SocketConnectionState.disconnected;
    socket?.disconnect();
    socket?.dispose();
  }

  void _applyAuth(io.Socket socket, String token) {
    socket.auth = {'token': token};
    try {
      socket.io.options?['query'] = {'token': token};
      socket.io.options?['auth'] = {'token': token};
    } catch (_) {}
  }

  Future<void> _recoverAuth() async {
    if (_refreshing || _token == null) return;
    final refresh = refreshAuth;
    if (refresh == null) return;
    _refreshing = true;
    try {
      final ok = await refresh();
      final next = tokenProvider?.call() ?? _token;
      if (ok && next != null && next.isNotEmpty) {
        updateToken(next);
      }
    } catch (e) {
      debugPrint('Socket.io refresh JWT: $e');
    } finally {
      _refreshing = false;
    }
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) {
      return data.map((key, value) => MapEntry(key, _jsonValue(value)));
    }
    if (data is Map) {
      return data.map(
        (key, value) => MapEntry(key.toString(), _jsonValue(value)),
      );
    }
    if (data is String) {
      try {
        return _asMap(jsonDecode(data));
      } catch (_) {
        return null;
      }
    }
    try {
      return _asMap(jsonDecode(jsonEncode(data)));
    } catch (_) {
      return null;
    }
  }

  dynamic _jsonValue(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, nested) => MapEntry(key.toString(), _jsonValue(nested)),
      );
    }
    if (value is List) {
      return value.map(_jsonValue).toList();
    }
    return value;
  }
}
