import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';

/// Phase 1 smoke screen: brand + API health check (no fake product data).
class FoundationScreen extends StatefulWidget {
  const FoundationScreen({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<FoundationScreen> createState() => _FoundationScreenState();
}

class _FoundationScreenState extends State<FoundationScreen>
    with SingleTickerProviderStateMixin {
  late final ApiClient _api;
  late final AnimationController _motion;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  String _statusLabel = 'Non vérifié';
  String _detail = 'Lance l’API puis appuie sur « Tester la connexion ».';
  bool _loading = false;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _api = widget.apiClient ?? ApiClient();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _motion, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic));
    _motion.forward();
  }

  @override
  void dispose() {
    _motion.dispose();
    if (widget.apiClient == null) {
      _api.dispose();
    }
    super.dispose();
  }

  Future<void> _checkHealth() async {
    setState(() {
      _loading = true;
      _detail = 'Contact de l’API…';
    });

    try {
      final data = await _api.getHealth();
      final db = data['database'] as Map<String, dynamic>?;
      setState(() {
        _ok = data['status'] == 'ok';
        _statusLabel = _ok ? 'API connectée' : 'API dégradée';
        _detail =
            'Env: ${data['environment'] ?? '?'} · DB enabled: ${db?['enabled']} · connected: ${db?['connected']}';
      });
    } catch (_) {
      setState(() {
        _ok = false;
        _statusLabel = 'API injoignable';
        _detail =
            'Vérifie que NestJS tourne sur le port 3000.\nURL: ${AppConfig.apiBaseUrl}/health';
      });
    } finally {
      setState(() => _loading = false);
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
            colors: [
              Color(0xFFE7F5EE),
              FutBoliaColors.surface,
              Color(0xFFDCEFE4),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FbBadge(label: 'PHASE 1 · FOUNDATION'),
                    const SizedBox(height: 28),
                    Text('MATCHARENA', style: textTheme.displayMedium),
                    const SizedBox(height: 12),
                    Text(
                      'Tournois, équipes et mercato — une plateforme pour le foot amateur.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: FutBoliaColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: FutBoliaColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: FutBoliaColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _ok ? Icons.check_circle : Icons.cloud_outlined,
                                color: _ok
                                    ? FutBoliaColors.success
                                    : FutBoliaColors.pitch,
                              ),
                              const SizedBox(width: 10),
                              Text(_statusLabel, style: textTheme.titleLarge),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(_detail, style: textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FbButton(
                      label: 'Tester la connexion API',
                      loading: _loading,
                      onPressed: _checkHealth,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aucune donnée fictive : cet écran vérifie uniquement le socle technique.',
                      style: textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
