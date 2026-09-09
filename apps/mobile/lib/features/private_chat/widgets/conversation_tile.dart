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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _isTournament
                      ? FutBoliaColors.lime
                      : const Color(0xFFE8F5E9),
                  child: Icon(
                    _isTournament
                        ? Icons.emoji_events_outlined
                        : Icons.person_outline,
                    color: FutBoliaColors.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: FutBoliaColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              unread > 0 ? FontWeight.w700 : FontWeight.w400,
                          color: FutBoliaColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  Badge(
                    label: Text('$unread'),
                    child: Icon(
                      _isTournament
                          ? Icons.forum_outlined
                          : Icons.chat_bubble_outline,
                      color: FutBoliaColors.pitchDark,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: FutBoliaColors.inkMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
