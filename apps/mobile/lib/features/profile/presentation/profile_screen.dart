import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/presentation/verify_email_screen.dart';
import '../../friends/friends_screen.dart';
import 'settings_tab.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Non connecté')));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: FutBoliaColors.surfaceDark,
        appBar: AppBar(
          title: Text(
            'Profil',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profil'),
              Tab(text: 'Amis'),
              Tab(text: 'Réglages'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProfileEditTab(),
            FriendsScreen(embedded: true),
            SettingsTab(),
          ],
        ),
      ),
    );
  }
}

class _ProfileEditTab extends StatefulWidget {
  const _ProfileEditTab();

  @override
  State<_ProfileEditTab> createState() => _ProfileEditTabState();
}

class _ProfileEditTabState extends State<_ProfileEditTab>
    with AutomaticKeepAliveClientMixin {
  final _city = TextEditingController();
  final _bio = TextEditingController();
  final _firstName = TextEditingController();
  bool _loading = false;
  bool _initialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthSession>().user;
    if (user != null) {
      _city.text = user.city ?? '';
      _bio.text = user.bio ?? '';
      _firstName.text = user.firstName ?? '';
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _city.dispose();
    _bio.dispose();
    _firstName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthSession>().updateProfile({
        'firstName':
            _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour')),
      );
    } catch (_) {
      if (!mounted) return;
      final msg =
          context.read<AuthSession>().errorMessage ?? 'Mise à jour impossible';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final session = context.watch<AuthSession>();
    final user = session.user;
    if (user == null) {
      return const Center(child: Text('Non connecté'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            image: const DecorationImage(
              image: AssetImage('assets/images/bg_stadium_night.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Color(0xAA070B09),
                BlendMode.darken,
              ),
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: FutBoliaColors.cardDark,
                child: Icon(
                  Icons.sports_soccer,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.displayPseudo,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FbBadge(
          label: user.emailVerified ? 'E-MAIL VÉRIFIÉ' : 'E-MAIL À VÉRIFIER',
          background:
              user.emailVerified ? FutBoliaColors.lime : const Color(0xFFFFE0B2),
        ),
        if (!user.emailVerified) ...[
          const SizedBox(height: 12),
          FbButton(
            label: 'Vérifier mon e-mail',
            variant: FbButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
              );
            },
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _firstName,
          decoration: const InputDecoration(labelText: 'Prénom (optionnel)'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _city,
          decoration: const InputDecoration(labelText: 'Ville'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _bio,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 24),
        FbButton(label: 'Enregistrer', loading: _loading, onPressed: _save),
      ],
    );
  }
}
