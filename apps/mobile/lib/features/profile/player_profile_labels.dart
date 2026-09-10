import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';

class PlayerProfileLabels {
  PlayerProfileLabels._();

  static const positionGroups = <String, List<(String code, String short, String label)>>{
    'Gardien': [('gb', 'GB', 'Gardien')],
    'Défense': [
      ('dg', 'DG', 'Défenseur gauche'),
      ('dc', 'DC', 'Défenseur central'),
      ('dd', 'DD', 'Défenseur droit'),
    ],
    'Milieu': [
      ('mg', 'MG', 'Milieu gauche'),
      ('mc', 'MC', 'Milieu'),
      ('md', 'MD', 'Milieu droit'),
      ('mcd', 'MCD', 'Milieu défensif'),
    ],
    'Attaque': [
      ('ag', 'AG', 'Ailier gauche'),
      ('bu', 'BU', 'Buteur'),
      ('ad', 'AD', 'Ailier droit'),
    ],
  };

  static const experience = <String, String>{
    'leisure': 'Loisir',
    'regular': 'Régulier',
    'competition': 'Compétition',
    'semi_pro': 'Semi-pro',
    'pro': 'Pro',
  };

  static const availability = <String, String>{
    'soir': 'Soir',
    'weekend': 'Week-end',
    'semaine': 'Semaine',
    'midi': 'Midi',
  };

  static const feet = <String, String>{
    'left': 'Gauche',
    'right': 'Droit',
    'both': 'Les deux',
  };

  static String position(String? code) {
    if (code == null || code.isEmpty) return '';
    for (final group in positionGroups.values) {
      for (final item in group) {
        if (item.$1 == code) return item.$2;
      }
    }
    return code.toUpperCase();
  }

  static String positionLong(String? code) {
    if (code == null || code.isEmpty) return '';
    for (final group in positionGroups.values) {
      for (final item in group) {
        if (item.$1 == code) return '${item.$2} · ${item.$3}';
      }
    }
    return code.toUpperCase();
  }

  static String experienceLabel(String? value) =>
      experience[value] ?? value ?? '';

  static String footLabel(String? value) => feet[value] ?? value ?? '';

  static String availabilityLabel(String? value) =>
      availability[value] ?? value ?? '';

  static String careerRole(String? value) {
    switch (value) {
      case 'organizer':
        return 'Orga';
      case 'captain':
        return 'Capitaine';
      case 'selector':
        return 'Sélectionneur';
      case 'host':
        return 'Hôte';
      case 'player':
        return 'Joueur';
      default:
        return value ?? '';
    }
  }

  static String formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }

  static String? avatarUrl(String? path, {String? userId}) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return path;
      }
      final suffix = path.startsWith('/') ? path : '/$path';
      return '${AppConfig.apiBaseUrl}$suffix';
    }
    if (userId == null || userId.isEmpty) return null;
    return null;
  }
}

List<String> normalizePositions(dynamic positions, String? legacy) {
  if (positions is List && positions.isNotEmpty) {
    return positions
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .take(5)
        .toList();
  }
  const map = {
    'gk': 'gb',
    'def': 'dc',
    'mid': 'mc',
    'fwd': 'bu',
  };
  final mapped = map[legacy];
  if (mapped != null) return [mapped];
  if (legacy != null &&
      legacy.isNotEmpty &&
      legacy != 'any' &&
      !map.containsKey(legacy)) {
    return [legacy];
  }
  return [];
}

int? asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

List<String> asStringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
}

/// `null` = annulé, `''` = aucun poste, sinon code FIFA (`gb`, `dc`, `bu`…).
Future<String?> pickFifaPosition(
  BuildContext context, {
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: SafeArea(
          child: ListView(
            children: [
              const ListTile(
                title: Text('Poste sur le terrain'),
                subtitle: Text('Gardien, défense, milieu, attaque'),
              ),
              ListTile(
                leading: Icon(
                  selected == null || selected.isEmpty
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
                title: const Text('Aucun poste'),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              ...PlayerProfileLabels.positionGroups.entries.expand((group) {
                return [
                  ListTile(
                    dense: true,
                    title: Text(
                      group.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ...group.value.map(
                    (item) => ListTile(
                      leading: Icon(
                        selected == item.$1
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                      ),
                      title: Text('${item.$2} · ${item.$3}'),
                      onTap: () => Navigator.pop(ctx, item.$1),
                    ),
                  ),
                ];
              }),
            ],
          ),
        ),
      );
    },
  );
}
