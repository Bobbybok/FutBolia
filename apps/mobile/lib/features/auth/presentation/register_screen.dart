import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/components/fb_atmosphere.dart';
import '../../../design_system/components/fb_brand.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../application/auth_session.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _pseudo = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _pseudo.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthSession>().register(
            email: _email.text,
            password: _password.text,
            pseudo: _pseudo.text,
          );
    } catch (_) {
      if (!mounted) return;
      final msg =
          context.read<AuthSession>().errorMessage ?? 'Inscription impossible';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: FbAtmosphere(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            const Center(child: FbBrandLogo(height: 140)),
            const SizedBox(height: 10),
            Text(
              'Choisis un pseudo unique. Tu pourras compléter ton profil ensuite.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _pseudo,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Pseudo',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Mot de passe (8 caractères min.)',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 28),
            FbButton(
              label: 'S’inscrire',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            Text(
              'Déjà un compte ?',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(
                'Se connecter',
                style: textTheme.bodyMedium?.copyWith(
                  color: FutBoliaColors.lime,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: FutBoliaColors.lime,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
