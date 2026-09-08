import 'package:flutter/material.dart';
import '../tokens/colors.dart';

class FbBadge extends StatelessWidget {
  const FbBadge({
    super.key,
    required this.label,
    this.background = FutBoliaColors.lime,
    this.foreground = FutBoliaColors.ink,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foreground,
          fontSize: 12,
        ),
      ),
    );
  }
}
