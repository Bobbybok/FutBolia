import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import 'admin_moderation_screen.dart';
import 'admin_permissions.dart';
import 'admin_security_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_tournaments_screen.dart';
import 'admin_users_screen.dart';
import 'manage_admins/grant_admin_screen.dart';
import 'manage_admins/grant_moderator_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().user!;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            user.isAdmin ? 'ADMIN' : 'MODÉRATION',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            user.isAdmin
                ? 'Outils plateforme. L’API décide des droits, pas l’écran.'
                : 'Signalements et messages. Reconnecte-toi si tes droits viennent d’être accordés.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: FutBoliaColors.inkMuted,
                ),
          ),
          const SizedBox(height: 24),
          if (user.hasPermission(AdminPermissions.manageAdmins))
            _AdminCard(
              title: 'Gérer les admins',
              subtitle: 'Accorder, modifier ou retirer des permissions',
              icon: Icons.admin_panel_settings_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GrantAdminScreen()),
                );
              },
            ),
          if (user.hasPermission(AdminPermissions.manageAdmins) ||
              user.hasPermission(AdminPermissions.manageModerators))
            _AdminCard(
              title: 'Modérateurs',
              subtitle: user.isAdmin
                  ? 'Nommer un modo, puis cocher ses droits'
                  : 'Nommer ou retirer un modo',
              icon: Icons.shield_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GrantModeratorScreen()),
                );
              },
            ),
          if (user.hasPermission(AdminPermissions.manageUsers))
            _AdminCard(
              title: 'Utilisateurs',
              subtitle: 'Recherche, ban, reset, historique',
              icon: Icons.people_outline,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                );
              },
            ),
          if (user.hasPermission(AdminPermissions.manageTournaments))
            _AdminCard(
              title: 'Tournois',
              subtitle: 'Tous les tournois, transfert, matchs, équipes',
              icon: Icons.emoji_events_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminTournamentsScreen()),
                );
              },
            ),
          if (user.hasPermission(AdminPermissions.moderateContent))
            _AdminCard(
              title: 'Modération',
              subtitle: 'Signalements et messages supprimés',
              icon: Icons.flag_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminModerationScreen()),
                );
              },
            ),
          if (user.hasPermission(AdminPermissions.viewStats))
            _AdminCard(
              title: 'Stats',
              subtitle: 'Utilisateurs, tournois, matchs',
              icon: Icons.insights_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminStatsScreen()),
                );
              },
            ),
          if (user.hasPermission(AdminPermissions.viewSecurity))
            _AdminCard(
              title: 'Sécurité',
              subtitle: 'Santé API, sessions, journal d’audit',
              icon: Icons.security_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminSecurityScreen()),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: FutBoliaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: FutBoliaColors.pitch),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: FutBoliaColors.inkMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right, color: FutBoliaColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
