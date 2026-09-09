import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../design_system/components/fb_brand.dart';
import '../../../design_system/tokens/colors.dart';
import '../../admin/admin_home_screen.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/presentation/verify_email_screen.dart';
import '../../chat/chat_overlay_controller.dart';
import '../../chat/chat_popup.dart';
import '../../pickup_matches/presentation/pickup_matches_screen.dart';
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

  static const _chatDestIndex = 3;
  static const _tabCount = 5;

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
      return;
    }
    if (state == AppLifecycleState.paused ||
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
    } catch (_) {}
  }

  void _selectTab(int dest) {
    if (dest == _chatDestIndex) {
      context.read<ChatOverlayController>().toggleInbox();
      return;
    }
    final i = dest > _chatDestIndex ? dest - 1 : dest;
    if (i == _index) {
      _navKeys[i].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _index = i);
    }
  }

  void _onPop(bool didPop) {
    if (didPop) return;
    final chat = context.read<ChatOverlayController>();
    if (chat.visible) {
      if (chat.canGoBack) {
        chat.goBack();
      } else {
        chat.close();
      }
      return;
    }
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
        child: _HomeTab(
          onOpenTournaments: () => _selectTab(1),
          onOpenMatches: () => _selectTab(2),
          onOpenMessages: () => _selectTab(3),
          onOpenProfile: () => _selectTab(4),
        ),
      ),
      _tabNavigator(index: 1, child: const TournamentsScreen()),
      _tabNavigator(index: 2, child: const PickupMatchesScreen()),
      _tabNavigator(index: 3, child: const ProfileScreen()),
      if (user.isStaff)
        _tabNavigator(index: 4, child: const AdminHomeScreen()),
    ];

    final chatOpen = context.watch<ChatOverlayController>().visible;
    final unreadLabel = _unread > 99 ? '99+' : '$_unread';
    final messagesIcon = Badge(
      isLabelVisible: _unread > 0 && !chatOpen,
      label: Text(unreadLabel),
      child: Icon(chatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline),
    );

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Accueil',
      ),
      const NavigationDestination(
        icon: Icon(Icons.emoji_events_outlined),
        selectedIcon: Icon(Icons.emoji_events),
        label: 'Tournois',
      ),
      const NavigationDestination(
        icon: Icon(Icons.sports_soccer_outlined),
        selectedIcon: Icon(Icons.sports_soccer),
        label: 'Matchs',
      ),
      NavigationDestination(
        icon: messagesIcon,
        selectedIcon: messagesIcon,
        label: 'Messages',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
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
    final selectedPage = _index > maxIndex ? 0 : _index;
    final selectedDest =
        selectedPage >= _chatDestIndex ? selectedPage + 1 : selectedPage;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPop(didPop),
      child: Stack(
        children: [
          Scaffold(
            body: IndexedStack(index: selectedPage, children: pages),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedDest,
              onDestinationSelected: _selectTab,
              destinations: destinations,
              height: 68,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            ),
            floatingActionButton: !user.emailVerified && _index == 0
                ? FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const VerifyEmailScreen(),
                        ),
                      );
                    },
                    backgroundColor: FutBoliaColors.clay,
                    foregroundColor: Colors.white,
                    label: const Text('Vérifier e-mail'),
                  )
                : null,
          ),
          const ChatOverlayLayer(),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.onOpenTournaments,
    required this.onOpenMatches,
    required this.onOpenMessages,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenTournaments;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().user!;
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: FutBoliaColors.surfaceDark,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const FbBrandHeader(),
            const SizedBox(height: 18),
            Text(
              'Salut ${user.displayPseudo}',
              style: textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              user.emailVerified
                  ? 'Ton compte est prêt pour la saison.'
                  : 'Vérifie ton e-mail pour créer ou rejoindre un tournoi.',
              style: textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 22),
            _HeroTile(
              title: 'TOURNOIS',
              subtitle: 'Découvre, crée et gère tes compétitions amateurs',
              asset: 'assets/images/bg_stadium_night.jpg',
              onTap: onOpenTournaments,
              height: 132,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _GridTile(
                    title: 'MATCHS',
                    icon: Icons.sports_soccer,
                    asset: 'assets/images/bg_pitch.jpg',
                    onTap: onOpenMatches,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GridTile(
                    title: 'MESSAGES',
                    icon: Icons.chat_bubble_outline,
                    tint: FutBoliaColors.pitchDark,
                    onTap: onOpenMessages,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GridTile(
              title: 'PROFIL',
              icon: Icons.person_outline,
              tint: const Color(0xFF163528),
              onTap: onOpenProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.onTap,
    this.height = 120,
  });

  final String title;
  final String subtitle;
  final String asset;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            image: DecorationImage(
              image: AssetImage(asset),
              fit: BoxFit.cover,
              colorFilter: const ColorFilter.mode(
                Color(0xAA0B3D2A),
                BlendMode.darken,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.asset,
    this.tint,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? asset;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 118,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: tint ?? FutBoliaColors.cardDark,
            image: asset == null
                ? null
                : DecorationImage(
                    image: AssetImage(asset!),
                    fit: BoxFit.cover,
                    colorFilter: const ColorFilter.mode(
                      Color(0x99070B09),
                      BlendMode.darken,
                    ),
                  ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const Spacer(),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
