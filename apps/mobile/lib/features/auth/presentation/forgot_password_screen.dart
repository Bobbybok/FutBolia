import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _api = ApiClient();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() => _loading = true);
    try {
      await _api.forgotPassword(_email.text.trim());
      setState(() => _sent = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si le compte existe, un e-mail a été envoyé (consulte les logs de l’API en développement).',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _loading = true);
    try {
      await _api.resetPassword(
        token: _token.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe mis à jour. Connecte-toi.')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Entre ton e-mail pour recevoir un lien de réinitialisation.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: FutBoliaColors.inkMuted,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: 16),
          FbButton(label: 'Envoyer', loading: _loading && !_sent, onPressed: _request),
          if (_sent) ...[
            const SizedBox(height: 28),
            TextField(
              controller: _token,
              decoration: const InputDecoration(labelText: 'Code reçu'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
            ),
            const SizedBox(height: 16),
            FbButton(
              label: 'Réinitialiser',
              loading: _loading,
              onPressed: _reset,
            ),
          ],
        ],
      ),
    );
  }
}
