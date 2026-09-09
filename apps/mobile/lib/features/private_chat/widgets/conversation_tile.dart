import 'package:flutter/material.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/domain/staff_label.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
  });

  final Map<String, dynamic> conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  bool get _isTournament => conversation['kind'] == 'tournament';

  @override
  Widget build(BuildContext context) {
    final last = conversation['lastMessage'];
    final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
    final preview = last is Map
        ? (last['body']?.toString() ?? '')
        : _isTournament
            ? 'Chat privé des participants'
            : 'Aucun message';
    final title = _isTournament
        ? (conversation['name']?.toString() ?? 'Tournoi')
        : staffPseudoOf(conversation['friend']);
    final visibility = conversation['visibility']?.toString();
    final subtitle = _isTournament && last is! Map
        ? preview
        : _isTournament && visibility != null
            ? '${visibility == 'private' ? 'Tournoi privé' : 'Tournoi public'} · $preview'
            : preview;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: CircleAvatar(
        backgroundColor: _isTournament
            ? Theme.of(context).colorScheme.primaryContainer
            : FutBoliaColors.lime,
        child: Icon(
          _isTournament ? Icons.emoji_events_outlined : Icons.person_outline,
          color: FutBoliaColors.ink,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
        ),
      ),
      trailing: unread > 0
          ? Badge(
              label: Text('$unread'),
              child: Icon(
                _isTournament
                    ? Icons.forum_outlined
                    : Icons.chat_bubble_outline,
              ),
            )
          : Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.65,
              ),
            ),
    );
  }
}
