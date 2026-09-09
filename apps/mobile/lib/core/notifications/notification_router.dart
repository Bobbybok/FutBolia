import 'package:flutter/material.dart';
import '../../features/friends/friends_screen.dart';
import '../../features/pickup_matches/presentation/pickup_match_detail_screen.dart';
import '../../features/private_chat/conversation_screen.dart';
import '../../features/chat/presentation/tournament_chat_screen.dart';
import '../../features/tournaments/presentation/tournament_detail_screen.dart';

final futboliaNavigatorKey = GlobalKey<NavigatorState>();

Map<String, String> notificationDataOf(Map<String, dynamic> raw) {
  return raw.map((key, value) => MapEntry(key, value?.toString() ?? ''));
}

Future<void> openFromNotification(Map<String, String> data) async {
  final nav = futboliaNavigatorKey.currentState;
  if (nav == null) return;
  final type = data['type'] ?? '';

  switch (type) {
    case 'tournament_message':
      final tournamentId = data['tournamentId'] ?? '';
      if (tournamentId.isEmpty) return;
      await openTournamentChat(
        nav.context,
        tournamentId: tournamentId,
        tournamentName: 'Chat tournoi',
      );
      return;
    case 'private_message':
      final conversationId = data['conversationId'] ?? '';
      if (conversationId.isEmpty) return;
      await openDirectChat(
        nav.context,
        conversationId: conversationId,
        friendName: 'Conversation',
        friendId: data['senderId'],
      );
      return;
    case 'friend_request':
    case 'friend_accepted':
      nav.push(MaterialPageRoute(builder: (_) => const FriendsScreen()));
      return;
    case 'tournament_invite':
      final targetId = data['targetId'] ?? '';
      if (targetId.isEmpty) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(tournamentId: targetId),
        ),
      );
      return;
    case 'pickup_invite':
      final targetId = data['targetId'] ?? '';
      if (targetId.isEmpty) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => PickupMatchDetailScreen(matchId: targetId),
        ),
      );
      return;
  }
}
