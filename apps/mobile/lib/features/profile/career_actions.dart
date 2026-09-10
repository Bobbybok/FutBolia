import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';

enum CareerDeleteChoice { fromProfile, event }

String careerEventLabel(String? kind) {
  switch (kind) {
    case 'tournament':
      return 'tournoi';
    case 'pickup_match':
      return 'match libre';
    default:
      return 'match';
  }
}

bool careerCanRemoveFromProfile(Map<String, dynamic> item) =>
    item['canRemoveFromProfile'] == true;

bool careerCanDeleteEvent(Map<String, dynamic> item) =>
    item['canDeleteEvent'] == true;

Future<CareerDeleteChoice?> confirmCareerDelete(
  BuildContext context,
  Map<String, dynamic> item, {
  required bool isOwnProfile,
}) async {
  var canRemove = careerCanRemoveFromProfile(item);
  final canDelete = careerCanDeleteEvent(item);
  if (!canRemove && !canDelete) {
    if (!isOwnProfile) return null;
    canRemove = true;
  }

  final label = careerEventLabel(item['kind']?.toString());
  final name = item['name']?.toString() ?? label;

  if (canRemove && canDelete) {
    return showModalBottomSheet<CareerDeleteChoice>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(name),
              subtitle: Text(
                isOwnProfile
                    ? 'Retirer de ton profil ou supprimer l’événement'
                    : 'Retirer du profil de ce joueur ou supprimer l’événement',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(
                isOwnProfile
                    ? 'Retirer de mon profil'
                    : 'Retirer de ce profil',
              ),
              subtitle: const Text(
                'L’événement reste pour les autres participants.',
              ),
              onTap: () => Navigator.pop(ctx, CareerDeleteChoice.fromProfile),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              iconColor: FutBoliaColors.danger,
              title: Text('Supprimer définitivement ce $label'),
              subtitle: const Text(
                'Orga / admin : équipes, scores et inscriptions concernés sont effacés.',
              ),
              onTap: () => Navigator.pop(ctx, CareerDeleteChoice.event),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  if (canDelete) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ce $label ?'),
        content: Text(
          '« $name » sera supprimé définitivement. Orga et admin seulement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: FutBoliaColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return ok == true ? CareerDeleteChoice.event : null;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        isOwnProfile ? 'Retirer de ton profil ?' : 'Retirer de ce profil ?',
      ),
      content: Text(
        '« $name » disparaît de ce profil. Le $label n’est pas supprimé pour les autres.',
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

  if (choice == CareerDeleteChoice.fromProfile) {
    return api.removeCareerItem(
      userId: profileUserId,
      itemType: kind,
      itemId: id,
    );
  }

  switch (kind) {
    case 'tournament':
      await api.deleteTournament(id);
      break;
    case 'pickup_match':
      await api.deletePickupMatch(id);
      break;
    default:
      await api.deleteMatch(id);
  }
  return null;
}
