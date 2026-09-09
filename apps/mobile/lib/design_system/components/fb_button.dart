import 'package:flutter/material.dart';
import '../tokens/colors.dart';

enum FbButtonVariant { primary, secondary, ghost }

class FbButton extends StatelessWidget {
  const FbButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = FbButtonVariant.primary,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final FbButtonVariant variant;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Text(label);

    switch (variant) {
      case FbButtonVariant.primary:
        return FilledButton(onPressed: loading ? null : onPressed, child: child);
      case FbButtonVariant.secondary:
        return OutlinedButton(
          onPressed: loading ? null : onPressed,
          child: child,
        );
      case FbButtonVariant.ghost:
        return TextButton(
          onPressed: loading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).brightness == Brightness.dark
                ? FutBoliaColors.lime
                : FutBoliaColors.pitch,
          ),
          child: child,
        );
    }
  }
}
