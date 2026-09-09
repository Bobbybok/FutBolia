import 'package:flutter/material.dart';
import '../../design_system/tokens/colors.dart';

Future<bool> confirmChatAction(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Confirmer',
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: FutBoliaColors.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}
