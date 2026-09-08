class AdminPermissions {
  AdminPermissions._();

  static const manageUsers = 'manage_users';
  static const manageTournaments = 'manage_tournaments';
  static const moderateContent = 'moderate_content';
  static const viewSecurity = 'view_security';
  static const viewStats = 'view_stats';
  static const manageAdmins = 'manage_admins';
  static const manageModerators = 'manage_moderators';

  static const all = [
    manageUsers,
    manageTournaments,
    moderateContent,
    viewSecurity,
    viewStats,
    manageAdmins,
    manageModerators,
  ];

  static const forModerators = [
    manageUsers,
    manageTournaments,
    moderateContent,
    viewSecurity,
    viewStats,
    manageModerators,
  ];

  static String label(String permission) {
    switch (permission) {
      case manageUsers:
        return 'Gérer les utilisateurs';
      case manageTournaments:
        return 'Gérer les tournois';
      case moderateContent:
        return 'Modérer le contenu';
      case viewSecurity:
        return 'Voir la sécurité';
      case viewStats:
        return 'Voir les stats';
      case manageAdmins:
        return 'Gérer les admins';
      case manageModerators:
        return 'Gérer les modérateurs';
      default:
        return permission;
    }
  }

  static String hint(String permission) {
    switch (permission) {
      case manageUsers:
        return 'Voir, bannir, reset mot de passe';
      case manageTournaments:
        return 'Modifier / supprimer tournois, matchs, équipes';
      case moderateContent:
        return 'Signalements, messages, forum';
      case viewSecurity:
        return 'Logs, santé API, sessions';
      case viewStats:
        return 'Tableau de bord (inscrits, matchs)';
      case manageAdmins:
        return 'Accorder ou retirer l’accès admin';
      case manageModerators:
        return 'Nommer ou retirer d’autres modos (modération par défaut)';
      default:
        return '';
    }
  }
}
