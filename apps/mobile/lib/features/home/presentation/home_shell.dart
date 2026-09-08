import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/presentation/verify_email_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../tournaments/presentation/tournaments_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = context.read<AuthSession>();
      if (session.consumePromptEmailVerification() &&
          !(session.user?.emailVerified ?? false)) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final user = session.user!;

    final pages = [
      _HomeTab(onOpenTournaments: () => setState(() => _index = 1)),
      const TournamentsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Tournois',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: !user.emailVerified && _index == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
                );
              },
              backgroundColor: FutBoliaColors.clay,
              foregroundColor: Colors.white,
              label: const Text('Vérifier e-mail'),
            )
          : null,
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onOpenTournaments});

  final VoidCallback onOpenTournaments;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().user!;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('FUTBOLIA', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            'Salut ${user.pseudo}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            user.emailVerified
                ? 'Ton compte est prêt pour les tournois.'
                : 'Vérifie ton e-mail pour créer ou rejoindre un tournoi.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: FutBoliaColors.inkMuted,
                ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: onOpenTournaments,
            child: const Text('Voir les tournois'),
          ),
        ],
      ),
    );
  }
}
