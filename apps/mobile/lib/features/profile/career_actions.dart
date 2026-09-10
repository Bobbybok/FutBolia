import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';

enum CareerDeleteChoice { fromProfile }

bool careerCanRemoveFromProfile(Map<String, dynamic> item) =>
    item['canRemoveFromProfile'] == true;

Future<CareerDeleteChoice?> confirmCareerDelete(
  BuildContext context,
  Map<String, dynamic> item, {
  required bool isOwnProfile,
}) async {
  var canRemove = careerCanRemoveFromProfile(item);
  if (!canRemove) {
    if (!isOwnProfile) return null;
    canRemove = true;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        isOwnProfile ? 'Retirer de ton profil ?' : 'Retirer de ce profil ?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: FutBoliaColors.danger),
          child: const Text('Retirer'),
        ),
      ],
    ),
  );
  return ok == true ? CareerDeleteChoice.fromProfile : null;
}

Future<Map<String, dynamic>?> applyCareerDelete({
  required ApiClient api,
  required Map<String, dynamic> item,
  required CareerDeleteChoice choice,
  required String profileUserId,
}) async {
  final id = item['id']?.toString() ?? '';
  final kind = item['kind']?.toString() ?? 'tournament';
  if (id.isEmpty) return null;

  return api.removeCareerItem(
    userId: profileUserId,
    itemType: kind,
    itemId: id,
  );
}
