import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/components/fb_atmosphere.dart';
import '../../../design_system/components/fb_brand.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../application/auth_session.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthSession>().login(
            email: _email.text,
            password: _password.text,
          );
    } catch (_) {
      if (!mounted) return;
      final msg =
          context.read<AuthSession>().errorMessage ?? 'Connexion impossible';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          children: [
            const SizedBox(height: 12),
            const Center(child: FbBrandLogo(height: 168)),
            const SizedBox(height: 10),
            Text(
              'Rejoins les tournois et vis ta passion !',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 36),
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
            Text(
              'Connecte-toi à ton espace',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 28),
            FbButton(
              label: 'Se connecter',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Tu es nouveau sur MatchArena ? ',
                  style: textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Créer un compte',
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
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: Text(
                  'Mot de passe oublié',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
