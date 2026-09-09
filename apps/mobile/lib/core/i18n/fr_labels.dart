/// Libellés français pour les valeurs métier renvoyées par l’API.
class FrLabels {
  FrLabels._();

  static String tournamentStatus(String? value) {
    switch (value) {
      case 'draft':
        return 'Brouillon';
      case 'registration_open':
        return 'Inscriptions ouvertes';
      case 'registration_closed':
        return 'Inscriptions fermées';
      case 'in_progress':
        return 'En cours';
      case 'finished':
        return 'Terminé';
      case 'cancelled':
        return 'Annulé';
      default:
        return value ?? '';
    }
  }

  static String tournamentMode(String? value) {
    switch (value) {
      case 'classic':
        return 'Classique';
      case 'selection':
        return 'Sélection';
      default:
        return value ?? '';
    }
  }

  static String visibility(String? value) {
    switch (value) {
      case 'public':
        return 'Public';
      case 'private':
        return 'Privé';
      default:
        return value ?? '';
    }
  }

  static String memberRole(String? value) {
    switch (value) {
      case 'organizer':
        return 'Organisateur';
      case 'selector':
        return 'Sélectionneur';
      case 'captain':
        return 'Capitaine';
      case 'player':
        return 'Joueur';
      default:
        return value ?? '';
    }
  }

  static String teamSlot(String? value) {
    switch (value) {
      case 'starter':
        return 'Titulaire';
      case 'substitute':
        return 'Remplaçant';
      default:
        return value ?? '';
    }
  }

  static String teamStatus(String? value) {
    switch (value) {
      case 'forming':
        return 'En formation';
      case 'complete':
        return 'Effectif complet';
      case 'validated':
        return 'Validée';
      default:
        return value ?? '';
    }
  }

  static String mercatoStatus(String? value) {
    switch (value) {
      case 'available':
        return 'Disponible';
      case 'offer_sent':
        return 'Offre envoyée';
      case 'in_negotiation':
        return 'En négociation';
      case 'recruited':
        return 'Recruté';
      case 'unavailable':
        return 'Indisponible';
      default:
        return value ?? '';
    }
  }

  static String matchStatus(String? value) {
    switch (value) {
      case 'scheduled':
        return 'À jouer';
      case 'open':
        return 'Places disponibles';
      case 'full':
        return 'Complet';
      case 'finished':
        return 'Terminé';
      case 'cancelled':
        return 'Annulé';
      default:
        return value ?? '';
    }
  }

  static String pickupSide(String? value) {
    switch (value) {
      case 'home':
        return 'Équipe A';
      case 'away':
        return 'Équipe B';
      default:
        return value ?? '';
    }
  }

  static String apiMessage(String message) {
    // Si l’API renvoie encore un message anglais connu, on le traduit côté app.
    const map = <String, String>{
      'Invalid credentials': 'Identifiants incorrects',
      'Email must be an email': 'L’e-mail n’est pas valide',
      'password must be longer than or equal to 8 characters':
          'Le mot de passe doit contenir au moins 8 caractères',
      'le code doit contenir exactement 6 chiffres':
          'Le code doit contenir exactement 6 chiffres',
      'Jeton invalide ou expiré': 'Code invalide ou expiré',
    };
    return map[message] ?? message;
  }
}
