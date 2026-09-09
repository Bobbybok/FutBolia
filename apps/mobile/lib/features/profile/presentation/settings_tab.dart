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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Thème sombre'),
          subtitle: const Text('Affichage clair ou sombre sur cet appareil'),
          value: settings.darkMode,
          onChanged: settings.setDarkMode,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notifications'),
          subtitle: const Text(
            'Alertes push. Tes conversations et le badge Chat restent actifs.',
          ),
          value: settings.notificationsEnabled,
          onChanged: (value) => _toggleNotifications(context, value),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: session.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Déconnexion'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FutBoliaColors.danger,
            side: const BorderSide(color: FutBoliaColors.danger),
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
