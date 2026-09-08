import 'package:flutter/material.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/domain/staff_label.dart';

class FriendTile extends StatelessWidget {
  const FriendTile({
    super.key,
    required this.user,
    this.onMessage,
    this.onUnfriend,
    this.trailing,
  });

  final Map<String, dynamic> user;
  final VoidCallback? onMessage;
  final VoidCallback? onUnfriend;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(staffPseudoOf(user)),
      subtitle: user['city'] == null || user['city'].toString().isEmpty
          ? null
          : Text(user['city'].toString()),
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
    );
  }
}
