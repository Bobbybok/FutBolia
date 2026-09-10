class FutBoliaUser {
  FutBoliaUser({
    required this.id,
    required this.email,
    required this.emailVerified,
    required this.pseudo,
    this.firstName,
    this.city,
    this.position,
    this.positions = const [],
    this.strongFoot,
    this.heightCm,
    this.weightKg,
    this.experienceLevel,
    this.playingSinceYear,
    this.availability = const [],
    this.level,
    this.bio,
    this.avatarUrl,
    this.role = 'user',
    this.permissions = const [],
  });

  final String id;
  final String email;
  final bool emailVerified;
  final String pseudo;
  final String? firstName;
  final String? city;
  final String? position;
  final List<String> positions;
  final String? strongFoot;
  final int? heightCm;
  final int? weightKg;
  final String? experienceLevel;
  final int? playingSinceYear;
  final List<String> availability;
  final int? level;
  final String? bio;
  final String? avatarUrl;
  final String role;
  final List<String> permissions;

  bool get isAdmin => role == 'admin' || role == 'super_admin';

  bool get isModerator => role == 'moderator';

  bool get isStaff => isAdmin || isModerator;

  String get displayPseudo {
    final name = pseudo.trim().isEmpty ? 'Joueur' : pseudo.trim();
    if (name.endsWith(' (admin)') || name.endsWith(' (modo)')) return name;
    if (isAdmin) return '$name (admin)';
    if (isModerator) return '$name (modo)';
    return name;
  }

  /// Si l’API n’envoie pas encore `permissions` (session ancienne / Render),
  /// un admin voit quand même les outils. L’API refuse les actions non autorisées.
  bool hasPermission(String permission) {
    if (!isStaff) return false;
    if (isAdmin && permissions.isEmpty) return true;
    if (isModerator && permissions.isEmpty) {
      return permission == 'moderate_content';
    }
    return permissions.contains(permission);
  }

  factory FutBoliaUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    final rawPerms = json['permissions'];
    return FutBoliaUser(
      id: json['id'] as String,
      email: json['email'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
      pseudo: profile['pseudo'] as String? ?? '',
      firstName: profile['firstName'] as String?,
      city: profile['city'] as String?,
      position: profile['position'] as String?,
      positions: _normalizePositions(
        profile['positions'],
        profile['position'] as String?,
      ),
      strongFoot: profile['strongFoot'] as String?,
      heightCm: _asInt(profile['heightCm']),
      weightKg: _asInt(profile['weightKg']),
      experienceLevel: profile['experienceLevel'] as String?,
      playingSinceYear: _asInt(profile['playingSinceYear']),
      availability: _asStringList(profile['availability']),
      level: _asInt(profile['level']),
      bio: profile['bio'] as String?,
      avatarUrl: profile['avatarUrl'] as String?,
      role: (json['role'] as String?) ??
          (json['globalRole'] as String?) ??
          'user',
      permissions: rawPerms is List
          ? rawPerms.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

List<String> _normalizePositions(dynamic positions, String? legacy) {
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

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
}
