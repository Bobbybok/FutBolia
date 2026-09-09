import 'package:flutter/material.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/domain/staff_label.dart';

class FriendTile extends StatelessWidget {
  const FriendTile({
    super.key,
    required this.user,
    this.onTap,
    this.onLongPress,
    this.onMessage,
    this.onUnfriend,
    this.onReport,
    this.trailing,
  });

  final Map<String, dynamic> user;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMessage;
  final VoidCallback? onUnfriend;
  final VoidCallback? onReport;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: CircleAvatar(
                backgroundColor: FutBoliaColors.lime,
                child: Text(
                  staffPseudoOf(user).isNotEmpty
                      ? staffPseudoOf(user)[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: FutBoliaColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(
                staffPseudoOf(user),
                style: const TextStyle(
                  color: FutBoliaColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: user['city'] == null || user['city'].toString().isEmpty
                  ? null
                  : Text(
                      user['city'].toString(),
                      style: const TextStyle(color: FutBoliaColors.inkMuted),
                    ),
              trailing: trailing ??
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onReport != null)
                        IconButton(
                          tooltip: 'Signaler',
                          onPressed: onReport,
                          icon: const Icon(Icons.flag_outlined),
                        ),
                      if (onMessage != null)
                        IconButton(
                          tooltip: 'Message',
                          onPressed: onMessage,
                          icon: const Icon(Icons.chat_bubble_outline),
                        ),
                      if (onUnfriend != null)
                        IconButton(
                          tooltip: 'Retirer',
                          onPressed: onUnfriend,
                          icon: const Icon(Icons.person_remove_outlined),
                          color: FutBoliaColors.danger,
                        ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
