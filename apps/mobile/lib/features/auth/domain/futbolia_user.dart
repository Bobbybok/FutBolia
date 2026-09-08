class FutBoliaUser {
  FutBoliaUser({
    required this.id,
    required this.email,
    required this.emailVerified,
    required this.pseudo,
    this.firstName,
    this.city,
    this.position,
    this.strongFoot,
    this.level,
    this.bio,
  });

  final String id;
  final String email;
  final bool emailVerified;
  final String pseudo;
  final String? firstName;
  final String? city;
  final String? position;
  final String? strongFoot;
  final int? level;
  final String? bio;

  factory FutBoliaUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    return FutBoliaUser(
      id: json['id'] as String,
      email: json['email'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
      pseudo: profile['pseudo'] as String? ?? '',
      firstName: profile['firstName'] as String?,
      city: profile['city'] as String?,
      position: profile['position'] as String?,
      strongFoot: profile['strongFoot'] as String?,
      level: profile['level'] as int?,
      bio: profile['bio'] as String?,
    );
  }
}
