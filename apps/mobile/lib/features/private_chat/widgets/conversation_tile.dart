import 'package:flutter/material.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/domain/staff_label.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final friend = conversation['friend'];
    final last = conversation['lastMessage'];
    final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
    final preview = last is Map
        ? (last['body']?.toString() ?? '')
        : 'Aucun message';

    return ListTile(
      onTap: onTap,
      title: Text(staffPseudoOf(friend)),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400,
          color: FutBoliaColors.inkMuted,
        ),
      ),
      trailing: unread > 0
          ? Badge(
              label: Text('$unread'),
              child: const Icon(Icons.chat_bubble_outline),
            )
          : const Icon(Icons.chevron_right, color: FutBoliaColors.inkMuted),
    );
  }
}
