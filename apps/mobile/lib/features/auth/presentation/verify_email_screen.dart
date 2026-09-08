import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final TextEditingController _code;
  bool _loading = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    final pending = context.read<AuthSession>().pendingEmailVerificationToken;
    // Prefill only for local DEV when the API returns the code (no mail provider).
    final prefill =
        pending != null && RegExp(r'^\d{6}$').hasMatch(pending) ? pending : '';
    _code = TextEditingController(text: prefill);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisis le code à 6 chiffres reçu par e-mail')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await context.read<AuthSession>().verifyEmail(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail vérifié')),
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      final msg =
          context.read<AuthSession>().errorMessage ?? 'Vérification impossible';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      final session = context.read<AuthSession>();
      final msg = await session.resendVerification();
      if (!mounted) return;
      final pending = session.pendingEmailVerificationToken;
      if (pending != null && RegExp(r'^\d{6}$').hasMatch(pending)) {
        _code.text = pending;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? 'Code renvoyé')),
      );
    } catch (_) {
      if (!mounted) return;
      final err =
          context.read<AuthSession>().errorMessage ?? 'Renvoi impossible';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthSession>().user?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Vérifier l’e-mail')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const FbBadge(label: 'REQUIS POUR LES TOURNOIS'),
          const SizedBox(height: 16),
          Text(
            email == null
                ? 'Entre le code à 6 chiffres reçu par e-mail.'
                : 'Un code à 6 chiffres a été envoyé à $email. Saisis-le ci-dessous.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: FutBoliaColors.inkMuted,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  letterSpacing: 8,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'Code à 6 chiffres',
              hintText: '••••••',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          FbButton(label: 'Vérifier', loading: _loading, onPressed: _submit),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _resending ? null : _resend,
            child: _resending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Renvoyer le code'),
          ),
        ],
      ),
    );
  }
}
