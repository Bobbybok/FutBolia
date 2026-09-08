import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/presentation/verify_email_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _city = TextEditingController();
  final _bio = TextEditingController();
  final _firstName = TextEditingController();
  bool _loading = false;
  bool _initialized = false;

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
        'firstName': _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour')),
      );
    } catch (_) {
      if (!mounted) return;
      final msg = context.read<AuthSession>().errorMessage ?? 'Mise à jour impossible';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final user = session.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Non connecté')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            onPressed: () => session.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(user.displayPseudo, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          FbBadge(
            label: user.emailVerified ? 'E-MAIL VÉRIFIÉ' : 'E-MAIL À VÉRIFIER',
            background: user.emailVerified ? FutBoliaColors.lime : const Color(0xFFFFE0B2),
          ),
          if (!user.emailVerified) ...[
            const SizedBox(height: 12),
            FbButton(
              label: 'Vérifier mon e-mail',
              variant: FbButtonVariant.secondary,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
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
      ),
    );
  }
}
