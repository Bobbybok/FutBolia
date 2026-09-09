import 'package:flutter/material.dart';
import '../tokens/colors.dart';

/// MatchArena mark (launcher-style M icon).
class FbBrandMark extends StatelessWidget {
  const FbBrandMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/images/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Full MatchArena logo (icon + wordmark).
class FbBrandLogo extends StatelessWidget {
  const FbBrandLogo({super.key, this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_matcharena.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class FbBrandWordmark extends StatelessWidget {
  const FbBrandWordmark({
    super.key,
    this.fontSize = 28,
    this.compact = false,
  });

  final double fontSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: compact ? 0.6 : 0.2,
      height: 1,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: compact ? 'MATCH' : 'Match',
            style: style.copyWith(color: Colors.white),
          ),
          TextSpan(
            text: compact ? 'ARENA' : 'Arena',
            style: style.copyWith(color: FutBoliaColors.lime),
          ),
        ],
      ),
    );
  }
}

class FbBrandHeader extends StatelessWidget {
  const FbBrandHeader({super.key, this.showWordmark = true});

  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const FbBrandMark(size: 28),
        if (showWordmark) ...[
          const SizedBox(width: 8),
          const FbBrandWordmark(fontSize: 14, compact: true),
        ],
      ],
    );
  }
}
