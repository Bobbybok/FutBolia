import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/updates/github_update_service.dart';
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
        const SizedBox(height: 12),
        const _UpdateSettingsCard(),
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

class _UpdateSettingsCard extends StatefulWidget {
  const _UpdateSettingsCard();

  @override
  State<_UpdateSettingsCard> createState() => _UpdateSettingsCardState();
}

class _UpdateSettingsCardState extends State<_UpdateSettingsCard> {
  final _updates = GithubUpdateService.instance;
  StreamSubscription<GithubUpdateProgress>? _progressSub;
  String _version = '';
  String _text = 'Vérifie les releases GitHub.';
  bool _busy = false;
  bool _applying = false;
  bool _available = false;
  double _pct = 0;

  @override
  void initState() {
    super.initState();
    _progressSub = _updates.progress.listen(
      (p) {
        if (!mounted) return;
        setState(() {
          _pct = p.pct;
          if (p.label.isNotEmpty) _text = p.label;
        });
      },
      onError: (_) {},
    );
    _loadVersion();
    _check();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = info.version);
    } catch (_) {}
  }

  Future<void> _check() async {
    if (_busy || _applying) return;
    setState(() {
      _busy = true;
      _text = 'Vérification GitHub…';
    });
    try {
      final s = await _updates.check();
      if (!mounted) return;
      setState(() {
        _available = s.available;
        _text = s.message;
        if (s.local.isNotEmpty) _version = s.local.replaceFirst(RegExp(r'^v'), '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    if (_busy || _applying) return;
    setState(() {
      _applying = true;
      _busy = true;
      _pct = 0.02;
      _text = 'Téléchargement GitHub…';
    });
    try {
      final s = await _updates.apply();
      if (!mounted) return;
      setState(() {
        _available = s.available && !s.install;
        _text = s.message;
        if (s.ok) _pct = 1;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _applying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionLabel = _version.isEmpty ? '' : 'v$_version';
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.system_update_alt_rounded,
              color: FutBoliaColors.lime,
            ),
            title: const Text(
              'Mises à jour',
              style: TextStyle(
                color: FutBoliaColors.inkDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              [
                if (versionLabel.isNotEmpty) versionLabel,
                _text,
              ].join(' · '),
              style: const TextStyle(color: FutBoliaColors.inkMuted),
            ),
          ),
          if (_applying || _busy) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _applying ? _pct.clamp(0, 1) : null,
                minHeight: 6,
                color: FutBoliaColors.lime,
                backgroundColor: FutBoliaColors.lineDark,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _check,
                child: Text(_busy && !_applying ? 'Vérification…' : 'Vérifier'),
              ),
              if (_available)
                FilledButton(
                  onPressed: _busy ? null : _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: FutBoliaColors.lime,
                    foregroundColor: FutBoliaColors.ink,
                  ),
                  child: const Text('Installer la mise à jour'),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
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
