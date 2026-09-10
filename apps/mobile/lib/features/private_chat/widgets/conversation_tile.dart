import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/moderation/word_filter.dart';
import '../../../core/settings/app_settings.dart';
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
  bool get _isTeam => conversation['kind'] == 'team';
  bool get _isInterTeam => conversation['kind'] == 'inter_team';

  @override
  Widget build(BuildContext context) {
    final last = conversation['lastMessage'];
    final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
    final filterOn = context.watch<AppSettings>().wordFilterEnabled;
    final preview = last is Map
        ? applyWordFilter(
            last['body']?.toString() ?? '',
            enabled: filterOn,
          )
        : _isTournament
            ? 'Chat privé des participants'
            : _isTeam
                ? 'Chat de l’équipe'
                : _isInterTeam
                    ? 'Chat des capitaines'
                    : 'Aucun message';
    final title = _isTournament
        ? (conversation['name']?.toString() ?? 'Tournoi')
        : _isTeam
            ? (conversation['name']?.toString() ?? 'Équipe')
            : _isInterTeam
                ? (conversation['name']?.toString() ?? 'Chat inter-équipes')
                : staffPseudoOf(conversation['friend']);
    final visibility = conversation['visibility']?.toString();
    final subtitle = _isTournament && last is! Map
        ? preview
        : _isTournament && visibility != null
            ? '${visibility == 'private' ? 'Tournoi privé' : 'Tournoi public'} · $preview'
            : _isTeam && conversation['tournamentName'] != null
                ? '${conversation['tournamentName']} · $preview'
                : _isInterTeam && conversation['tournamentName'] != null
                    ? '${conversation['tournamentName']} · $preview'
                    : preview;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: FutBoliaColors.cardDark,
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
                      ? FutBoliaColors.lime.withValues(alpha: 0.22)
                      : _isTeam
                          ? FutBoliaColors.badgeInfo
                          : _isInterTeam
                              ? const Color(0xFF3D2A12)
                              : FutBoliaColors.badgeSoft,
                  child: Icon(
                    _isTournament
                        ? Icons.emoji_events_outlined
                        : _isTeam
                            ? Icons.groups_outlined
                            : _isInterTeam
                                ? Icons.hub_outlined
                                : Icons.person_outline,
                    color: _isTournament
                        ? FutBoliaColors.lime
                        : FutBoliaColors.inkDark,
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
                              color: FutBoliaColors.inkDark,
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
                      color: FutBoliaColors.lime,
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
