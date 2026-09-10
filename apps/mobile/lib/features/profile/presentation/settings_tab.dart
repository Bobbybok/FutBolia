import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final session = context.watch<AuthSession>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SettingsCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Notifications',
                  style: TextStyle(
                    color: FutBoliaColors.inkDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Alertes push. Tes conversations et le badge Chat restent actifs.',
                  style: TextStyle(color: FutBoliaColors.inkMuted),
                ),
                value: settings.notificationsEnabled,
                onChanged: (value) => _toggleNotifications(context, value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Filtre de mots',
                  style: TextStyle(
                    color: FutBoliaColors.inkDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Masque les insultes dans les chats et les bios. Désactive pour tout voir. L’équipe de modération voit toujours le texte original.',
                  style: TextStyle(color: FutBoliaColors.inkMuted),
                ),
                value: settings.wordFilterEnabled,
                onChanged: settings.setWordFilterEnabled,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: session.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Déconnexion'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: FutBoliaColors.danger.withValues(alpha: 0.18),
            side: const BorderSide(color: FutBoliaColors.danger),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleNotifications(BuildContext context, bool enabled) async {
    final settings = context.read<AppSettings>();
    final api = context.read<AuthSession>().api;
    await settings.setNotificationsEnabled(enabled);
    if (!context.mounted) return;
    if (enabled) {
      await PushNotificationService.instance.start(api);
    } else {
      await PushNotificationService.instance.stop(api);
    }
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FutBoliaColors.cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: FutBoliaColors.lime.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: child,
      ),
    );
  }
}
