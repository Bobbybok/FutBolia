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
  final _state = ValueNotifier<SocketConnectionState>(
    SocketConnectionState.disconnected,
  );

  final _tournamentMessage =
      StreamController<Map<String, dynamic>>.broadcast();
  final _tournamentMessageDeleted =
      StreamController<Map<String, dynamic>>.broadcast();
  final _tournamentChatCleared =
      StreamController<Map<String, dynamic>>.broadcast();
  final _privateMessage = StreamController<Map<String, dynamic>>.broadcast();
  final _privateMessageDeleted =
      StreamController<Map<String, dynamic>>.broadcast();
  final _friendRequest = StreamController<Map<String, dynamic>>.broadcast();
  final _friendAccepted = StreamController<Map<String, dynamic>>.broadcast();
  final _eventInvite = StreamController<Map<String, dynamic>>.broadcast();

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
  Stream<Map<String, dynamic>> get onPrivateMessage => _privateMessage.stream;
  Stream<Map<String, dynamic>> get onPrivateMessageDeleted =>
      _privateMessageDeleted.stream;
  Stream<Map<String, dynamic>> get onFriendRequest => _friendRequest.stream;
  Stream<Map<String, dynamic>> get onFriendAccepted => _friendAccepted.stream;
  Stream<Map<String, dynamic>> get onEventInvite => _eventInvite.stream;
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
          .setReconnectionDelay(800)
          .setReconnectionDelayMax(12000)
          .setAuth({'token': token})
          .setQuery({'token': token})
          .enableForceNew()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      debugPrint('Socket.io connecté');
      _state.value = SocketConnectionState.connected;
      socket.emit('app:foreground');
      _rejoinTournaments();
    });
    socket.onDisconnect((_) {
      debugPrint('Socket.io déconnecté');
      if (_token != null) {
        _state.value = SocketConnectionState.connecting;
      } else {
        _state.value = SocketConnectionState.disconnected;
      }
    });
    socket.onConnectError((err) {
      debugPrint('Socket.io connect_error: $err');
      _state.value = SocketConnectionState.connecting;
      unawaited(_recoverAuth());
    });
    socket.onError((err) {
      debugPrint('Socket.io error: $err');
    });
    socket.onReconnect((_) {
      _state.value = SocketConnectionState.connected;
      socket.emit('app:foreground');
      _rejoinTournaments();
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

    socket.connect();
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

  void _rejoinTournaments() {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    for (final id in _joinedTournaments) {
      socket.emit('joinTournament', {'tournamentId': id});
    }
  }

  void disconnect() {
    _token = null;
    _joinedTournaments.clear();
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
