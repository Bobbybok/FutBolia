import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../application/auth_session.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final TextEditingController _token;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final pending = context.read<AuthSession>().pendingEmailVerificationToken;
    _token = TextEditingController(text: pending ?? '');
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthSession>().verifyEmail(_token.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail vérifié')),
      );
    } catch (_) {
      if (!mounted) return;
      final msg = context.read<AuthSession>().errorMessage ?? 'Vérification impossible';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérifier l’e-mail')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const FbBadge(label: 'REQUIS POUR LES TOURNOIS'),
          const SizedBox(height: 16),
          Text(
            'En développement, le code de vérification est renvoyé par l’API et prérempli si disponible. '
            'Sinon, copie-le depuis les logs du serveur.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: FutBoliaColors.inkMuted,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _token,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Code de vérification',
            ),
          ),
          const SizedBox(height: 20),
          FbButton(label: 'Vérifier', loading: _loading, onPressed: _submit),
        ],
      ),
    );
  }
}
