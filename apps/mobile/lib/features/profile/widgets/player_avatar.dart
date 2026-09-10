import 'package:flutter/material.dart';
import '../../../design_system/tokens/colors.dart';
import '../player_profile_labels.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    this.userId,
    this.avatarUrl,
    this.radius = 42,
    this.onTap,
  });

  final String? userId;
  final String? avatarUrl;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = PlayerProfileLabels.avatarUrl(avatarUrl, userId: userId);
    final image = url == null
        ? null
        : NetworkImage(url);
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: FutBoliaColors.surfaceDark,
      backgroundImage: image,
      onBackgroundImageError: image == null ? null : (_, _) {},
      child: image == null
          ? Icon(
              Icons.sports_soccer,
              size: radius,
              color: Colors.white.withValues(alpha: 0.9),
            )
          : null,
    );

    if (onTap == null) return avatar;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          avatar,
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: FutBoliaColors.lime,
              shape: BoxShape.circle,
              border: Border.all(color: FutBoliaColors.surfaceDark, width: 2),
            ),
            child: Icon(
              Icons.photo_camera_outlined,
              size: radius * 0.32,
              color: FutBoliaColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
