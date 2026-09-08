import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      final msg = context.read<AuthSession>().errorMessage ?? 'Inscription impossible';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Choisis un pseudo unique. Tu pourras compléter ton profil ensuite.',
            style: textTheme.bodyLarge?.copyWith(color: FutBoliaColors.inkMuted),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _pseudo,
            decoration: const InputDecoration(labelText: 'Pseudo'),
          ),
          const SizedBox(height: 14),
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
            decoration: const InputDecoration(
              labelText: 'Mot de passe (8 caractères min.)',
            ),
          ),
          const SizedBox(height: 24),
          FbButton(label: 'S’inscrire', loading: _loading, onPressed: _submit),
        ],
      ),
    );
  }
}
