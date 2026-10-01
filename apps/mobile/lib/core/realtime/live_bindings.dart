import 'dart:async';
import 'package:flutter/widgets.dart';
import 'socket_service.dart';

/// Reloads a screen when the API broadcasts a live change.
class LiveBindings {
  final _subs = <StreamSubscription>[];
  Timer? _debounce;

  void listenTournament(
    String tournamentId,
    void Function(Map<String, dynamic> event) onChange,
  ) {
    final socket = SocketService.instance;
    socket.joinTournament(tournamentId);
    _subs.add(socket.onTournamentUpdated.listen((event) {
      if (event['tournamentId']?.toString() == tournamentId) {
        _run(() => onChange(event));
      }
    }));
  }

  void listenPickup(
    String matchId,
    void Function(Map<String, dynamic> event) onChange,
  ) {
    final socket = SocketService.instance;
    socket.joinPickup(matchId);
    _subs.add(socket.onPickupUpdated.listen((event) {
      if (event['matchId']?.toString() == matchId) {
        _run(() => onChange(event));
      }
    }));
  }

  void listenLobby(String kind, VoidCallback onChange) {
    _subs.add(SocketService.instance.onLobbyChanged.listen((event) {
      if (event['kind']?.toString() == kind) {
        _run(onChange);
      }
    }));
  }

  void _run(VoidCallback onChange) {
    _debounce?.cancel();
    // Defer past the current frame so socket-driven setState / Navigator
    // calls never run while a route transition has the navigator locked.
    _debounce = Timer(const Duration(milliseconds: 250), () {
      WidgetsBinding.instance.addPostFrameCallback((_) => onChange());
    });
  }

  void dispose() {
    _debounce?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
  }
}
