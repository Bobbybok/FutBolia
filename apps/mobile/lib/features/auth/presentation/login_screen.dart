import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      final msg = context.read<AuthSession>().errorMessage ?? 'Connexion impossible';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE7F5EE), FutBoliaColors.surface, Color(0xFFDCEFE4)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            children: [
              Text('FUTBOLIA', style: textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Connecte-toi pour rejoindre tournois et mercato.',
                style: textTheme.bodyLarge?.copyWith(color: FutBoliaColors.inkMuted),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
              ),
              const SizedBox(height: 24),
              FbButton(label: 'Se connecter', loading: _loading, onPressed: _submit),
              const SizedBox(height: 12),
              FbButton(
                label: 'Créer un compte',
                variant: FbButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
              ),
              FbButton(
                label: 'Mot de passe oublié',
                variant: FbButtonVariant.ghost,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
