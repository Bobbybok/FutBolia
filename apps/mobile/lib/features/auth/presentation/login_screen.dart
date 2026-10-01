import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/components/fb_atmosphere.dart';
import '../../../design_system/components/fb_brand.dart';
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
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  static const _accent = Color(0xFF2ECC71);
  static const _accentSoft = Color(0xFFB8E86C);
  static const _fieldFill = Color(0x99000000);
  static const _fieldBorder = Color(0x66FFFFFF);

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final raw = _login.text.trim();
      if (raw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indique ton e-mail ou ton pseudo')),
        );
        return;
      }
      final asEmail = raw.contains('@');
      await context.read<AuthSession>().login(
            email: asEmail ? raw : null,
            pseudo: asEmail ? null : raw,
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

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0x99FFFFFF), fontSize: 15),
      prefixIcon: Icon(prefix, color: Colors.white),
      suffixIcon: suffix,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: _accent, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // Keep the stadium photo fixed when the keyboard / text focus opens.
      resizeToAvoidBottomInset: false,
      body: FbAtmosphere(
        asset: 'assets/images/bg_login.jpg',
        overlayOpacity: 0.45,
        lockToScreen: true,
        // Show the full height of the photo (no vertical crop / zoom jump).
        fit: BoxFit.fitHeight,
        alignment: Alignment.center,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            28,
            36,
            28,
            28 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            const Center(child: FbBrandLogo(height: 150)),
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Ton prochain match\n',
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  TextSpan(
                    text: 'commence ici',
                    style: textTheme.titleLarge?.copyWith(
                      color: _accent,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            TextField(
              controller: _login,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration(
                hint: 'E-mail ou pseudo',
                prefix: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration(
                hint: 'Mot de passe',
                prefix: Icons.lock_outline,
                suffix: IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: _accentSoft,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.black,
                        ),
                      )
                    : const Text('Se connecter'),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0x55FFFFFF))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0x55FFFFFF))),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: _loading
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accentSoft,
                  side: const BorderSide(color: _accentSoft, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                child: const Text('Créer un compte'),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'En continuant, tu acceptes les conditions d’utilisation et la politique de confidentialité.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white38,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
