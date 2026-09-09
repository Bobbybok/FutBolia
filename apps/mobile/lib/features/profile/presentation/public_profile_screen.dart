String? userIdOf(dynamic value) {
  if (value is! Map) return null;
  for (final key in ['userId', 'authorId']) {
    final v = value[key]?.toString();
    if (v != null && v.isNotEmpty) return v;
  }
  final nested = value['user'];
  if (nested is Map) {
    final v = nested['id']?.toString();
    if (v != null && v.isNotEmpty) return v;
  }
  final friend = value['friend'];
  if (friend is Map) {
    final v = friend['id']?.toString();
    if (v != null && v.isNotEmpty) return v;
  }
  if (value['body'] == null && value['content'] == null) {
    final v = value['id']?.toString();
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

