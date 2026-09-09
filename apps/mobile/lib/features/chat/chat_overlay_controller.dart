import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';

enum ChatOverlayPage { inbox, dm, tournament }

class ChatOverlayController extends ChangeNotifier {
  bool _visible = false;
  bool _pinned = true;
  Offset? _offset;

  ChatOverlayPage page = ChatOverlayPage.inbox;

  String? conversationId;
  String? friendName;
  String? friendId;
  bool canSend = true;

  String? tournamentId;
  String? tournamentName;
  bool isOrganizer = false;
  bool canClearForEveryone = false;
  bool restoreInInbox = false;

  bool get visible => _visible;
  bool get pinned => _pinned;
  Offset? get offset => _offset;
  bool get canGoBack =>
      _visible && page != ChatOverlayPage.inbox;

  String get title {
    switch (page) {
      case ChatOverlayPage.inbox:
        return 'Chat';
      case ChatOverlayPage.dm:
        return friendName ?? 'Conversation';
      case ChatOverlayPage.tournament:
        return tournamentName ?? 'Tournoi';
    }
  }

  void toggleInbox() {
    if (_visible) {
      close();
      return;
    }
    openInbox();
  }

  void openInbox() {
    _visible = true;
    page = ChatOverlayPage.inbox;
    notifyListeners();
  }

  void openDm({
    required String conversationId,
    required String friendName,
    String? friendId,
    bool canSend = true,
  }) {
    this.conversationId = conversationId;
    this.friendName = friendName;
    this.friendId = friendId;
    this.canSend = canSend;
    _visible = true;
    page = ChatOverlayPage.dm;
    notifyListeners();
  }

  void openTournament({
    required String tournamentId,
    required String tournamentName,
    bool isOrganizer = false,
    bool canClearForEveryone = false,
    bool canSend = true,
    bool restoreInInbox = false,
  }) {
    this.tournamentId = tournamentId;
    this.tournamentName = tournamentName;
    this.isOrganizer = isOrganizer;
    this.canClearForEveryone = canClearForEveryone;
    this.canSend = canSend;
    this.restoreInInbox = restoreInInbox;
    _visible = true;
    page = ChatOverlayPage.tournament;
    notifyListeners();
  }

  void goBack() => openInbox();

  void togglePin() {
    _pinned = !_pinned;
    notifyListeners();
  }

  void setOffset(Offset offset) {
    _offset = offset;
  }

  void close() {
    if (!_visible) return;
    _visible = false;
    page = ChatOverlayPage.inbox;
    notifyListeners();
  }
}
