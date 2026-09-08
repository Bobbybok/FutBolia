String staffDisplayPseudo(String? pseudo, [String? role]) {
  final raw = (pseudo ?? '').trim();
  final name = raw.isEmpty ? 'Joueur' : raw;
  if (name.endsWith(' (admin)') || name.endsWith(' (modo)')) {
    return name;
  }
  switch (role) {
    case 'admin':
    case 'super_admin':
      return '$name (admin)';
    case 'moderator':
      return '$name (modo)';
    default:
      return name;
  }
}

String staffPseudoOf(dynamic userOrMap) {
  if (userOrMap is Map) {
    return staffDisplayPseudo(
      userOrMap['pseudo']?.toString(),
      userOrMap['role']?.toString(),
    );
  }
  return staffDisplayPseudo(userOrMap?.toString());
}
