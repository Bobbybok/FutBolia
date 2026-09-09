import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../design_system/tokens/colors.dart';
import '../../admin/admin_home_screen.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/presentation/verify_email_screen.dart';
import '../../pickup_matches/presentation/pickup_matches_screen.dart';
import '../../private_chat/conversations_list_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../tournaments/presentation/tournaments_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  int _unread = 0;
  StreamSubscription<void>? _inboxSub;

  static const _messagesTabIndex = 3;
  static const _tabCount = 6;

  final _navKeys = List<GlobalKey<NavigatorState>>.generate(
    _tabCount,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = context.read<AuthSession>();
      if (session.consumePromptEmailVerification() &&
          !(session.user?.emailVerified ?? false)) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
        );
      }
      _refreshUnread();
    });
    _inboxSub = SocketService.instance.onInboxPing.listen((_) {
      _refreshUnread();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inboxSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SocketService.instance.setForeground(true);
      _refreshUnread();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      SocketService.instance.setForeground(false);
    }
  }

  Future<void> _refreshUnread() async {
    try {
      final api = context.read<AuthSession>().api;
      final counts = await Future.wait([
        api.conversationsUnreadCount(),
        api.tournamentChatUnreadCount(),
      ]);
      if (!mounted) return;
      setState(() => _unread = counts[0] + counts[1]);
    } catch (_) {
      // Badge optionnel : une panne réseau ne bloque pas la nav.
    }
  }

  void _selectTab(int i) {
    if (i == _index) {
      _navKeys[i].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _index = i);
    }
    if (i == _messagesTabIndex) _refreshUnread();
  }

  void _onPop(bool didPop) {
    if (didPop) return;
    final nav = _navKeys[_index].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }
    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }
    SystemNavigator.pop();
  }

  Widget _tabNavigator({required int index, required Widget child}) {
    return Navigator(
      key: _navKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final user = session.user!;

    final pages = [
      _tabNavigator(
        index: 0,
        child: _HomeTab(onOpenTournaments: () => _selectTab(1)),
      ),
      _tabNavigator(index: 1, child: const TournamentsScreen()),
      _tabNavigator(index: 2, child: const PickupMatchesScreen()),
      _tabNavigator(index: 3, child: const ConversationsListScreen()),
      _tabNavigator(index: 4, child: const ProfileScreen()),
      if (user.isStaff)
        _tabNavigator(index: 5, child: const AdminHomeScreen()),
    ];

    final unreadLabel = _unread > 99 ? '99+' : '$_unread';
    final messagesIcon = Badge(
      isLabelVisible: _unread > 0,
      label: Text(unreadLabel),
      child: const Icon(Icons.chat_bubble_outline),
    );

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        label: 'Accueil',
      ),
      const NavigationDestination(
        icon: Icon(Icons.emoji_events_outlined),
        label: 'Tournois',
      ),
      const NavigationDestination(
        icon: Icon(Icons.sports_soccer_outlined),
        label: 'Matchs',
      ),
      NavigationDestination(
        icon: messagesIcon,
        label: 'Messages',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        label: 'Profil',
      ),
      if (user.isStaff)
        NavigationDestination(
          icon: Icon(
            user.isAdmin
                ? Icons.admin_panel_settings_outlined
                : Icons.shield_outlined,
          ),
          label: user.isAdmin ? 'Admin' : 'Modo',
        ),
    ];

    final maxIndex = pages.length - 1;
    final selected = _index > maxIndex ? 0 : _index;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPop(didPop),
      child: Scaffold(
        body: IndexedStack(index: selected, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: _selectTab,
          destinations: destinations,
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
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onOpenTournaments});

  final VoidCallback onOpenTournaments;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().user!;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('FUTBOLIA', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            'Salut ${user.displayPseudo}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            user.emailVerified
                ? 'Ton compte est prêt pour les tournois.'
                : 'Vérifie ton e-mail pour créer ou rejoindre un tournoi.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: muted),
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
