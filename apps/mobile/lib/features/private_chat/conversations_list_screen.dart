import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/realtime/socket_service.dart';
import '../../design_system/components/fb_atmosphere.dart';
import '../../design_system/components/fb_brand.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../chat/chat_actions.dart';
import '../chat/chat_overlay_controller.dart';
import '../chat/presentation/tournament_chat_screen.dart';
import '../chat/presentation/team_chat_screen.dart';
import '../moderation/report_sheet.dart';
import '../profile/presentation/public_profile_screen.dart';
import '../tournaments/presentation/tournament_detail_screen.dart';
import 'conversation_screen.dart';
import 'widgets/conversation_tile.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  StreamSubscription<void>? _inboxSub;

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _reload();
    _inboxSub = SocketService.instance.onInboxPing.listen((_) {
      _reloadQuiet();
    });
  }

  @override
  void dispose() {
    _inboxSub?.cancel();
    super.dispose();
  }

  Future<void> _reloadQuiet() async {
    if (!mounted || _loading) return;
    try {
      final results = await Future.wait([
        _api.listConversations(),
        _api.listTournamentChats(),
      ]);
      if (!mounted) return;
      final dms = results[0]
          .map((c) => {...c, 'kind': c['kind'] ?? 'dm'})
          .toList();
      final tournaments = results[1];
      final items = [...tournaments, ...dms]
          .where((e) => e['kind'] != 'inter_team')
          .toList();
      items.sort((a, b) => _updatedAt(b).compareTo(_updatedAt(a)));
      setState(() => _items = items);
    } catch (_) {}
  }

  DateTime _updatedAt(Map<String, dynamic> item) {
    final raw = item['updatedAt'] ??
        (item['lastMessage'] is Map ? item['lastMessage']['createdAt'] : null);
    return DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.listConversations(),
        _api.listTournamentChats(),
      ]);
      if (!mounted) return;
      final dms = results[0]
          .map((c) => {...c, 'kind': c['kind'] ?? 'dm'})
          .toList();
      final tournaments = results[1];
      final items = [...tournaments, ...dms]
          .where((e) => e['kind'] != 'inter_team')
          .toList();
      items.sort((a, b) => _updatedAt(b).compareTo(_updatedAt(a)));
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Chargement impossible';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> conversation) async {
    if (conversation['kind'] == 'tournament') {
      openTournamentChat(
        context,
        tournamentId: conversation['tournamentId']?.toString() ??
            conversation['id'] as String,
        tournamentName: conversation['name']?.toString() ?? 'Tournoi',
        isOrganizer: conversation['isOrganizer'] == true,
        canClearForEveryone: false,
      );
    } else if (conversation['kind'] == 'team') {
      openTeamChat(
        context,
        teamId: conversation['teamId']?.toString() ??
            conversation['id'] as String,
        teamName: conversation['name']?.toString() ?? 'Équipe',
        canClearForEveryone: false,
      );
    } else if (conversation['kind'] == 'inter_team') {
      return;
    } else {
      openDirectChat(
        context,
        conversationId: conversation['id'] as String,
        friendName: conversationFriendName(conversation),
        friendId: userIdOf(conversation),
        canSend: conversation['canSend'] != false,
      );
    }
  }

  Future<void> _conversationActions(Map<String, dynamic> conversation) async {
    if (conversation['kind'] == 'tournament') {
      final tournamentId =
          conversation['tournamentId']?.toString() ??
              conversation['id'] as String;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useRootNavigator: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('Ouvrir le tournoi'),
                onTap: () {
                  Navigator.pop(ctx);
                  final overlay = context.read<ChatOverlayController>();
                  if (!overlay.pinned) overlay.close();
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => TournamentDetailScreen(
                        tournamentId: tournamentId,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers_clear_outlined),
                title: const Text('Vider le chat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _clearTournament(tournamentId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Supprimer la conversation'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _hideTournament(tournamentId);
                },
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (conversation['kind'] == 'team') {
      final teamId =
          conversation['teamId']?.toString() ?? conversation['id'] as String;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useRootNavigator: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.layers_clear_outlined),
                title: const Text('Vider le chat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _clearTeam(teamId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Supprimer la conversation'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _hideTeam(teamId);
                },
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (conversation['kind'] == 'inter_team') {
      final tournamentId =
          conversation['tournamentId']?.toString() ??
              conversation['id'] as String;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useRootNavigator: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('Ouvrir le tournoi'),
                onTap: () {
                  Navigator.pop(ctx);
                  final overlay = context.read<ChatOverlayController>();
                  if (!overlay.pinned) overlay.close();
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => TournamentDetailScreen(
                        tournamentId: tournamentId,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers_clear_outlined),
                title: const Text('Vider le chat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _clearInterTeam(tournamentId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Supprimer la conversation'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _hideInterTeam(tournamentId);
                },
              ),
            ],
          ),
        ),
      );
      return;
    }
    final id = conversation['id'] as String;
    final userId = userIdOf(conversation);
    final name = conversationFriendName(conversation);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.layers_clear_outlined),
              title: const Text('Vider le chat'),
              onTap: () async {
                Navigator.pop(ctx);
                await _clearDm(id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Supprimer la conversation'),
              onTap: () async {
                Navigator.pop(ctx);
                await _hideDm(id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.outlined_flag),
              title: const Text('Signaler le joueur'),
              onTap: () {
                Navigator.pop(ctx);
                if (userId == null) return;
                showReportSheet(
                  context,
                  type: 'user',
                  targetId: userId,
                  title: 'Signaler $name',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _clearDm(String id) async {
    final ok = await confirmChatAction(
      context,
      title: 'Vider le chat ?',
      body: 'L’historique disparaît pour toi. L’autre personne le garde.',
      confirmLabel: 'Vider',
    );
    if (!ok) return;
    await _run(() => _api.clearConversation(id));
  }

  Future<void> _hideDm(String id) async {
    final ok = await confirmChatAction(
      context,
      title: 'Supprimer la conversation ?',
      body:
          'Elle disparaît de ta liste. Un nouveau message la fera réapparaître, sans l’ancien historique.',
      confirmLabel: 'Supprimer',
    );
    if (!ok) return;
    await _run(() => _api.hideConversation(id));
  }

  Future<void> _clearTournament(String id) async {
    final ok = await confirmChatAction(
      context,
      title: 'Vider le chat ?',
      body: 'L’historique disparaît pour toi. Les autres participants le gardent.',
      confirmLabel: 'Vider',
    );
    if (!ok) return;
    await _run(() => _api.clearTournamentChat(id));
  }

  Future<void> _hideTournament(String id) async {
    final ok = await confirmChatAction(
      context,
      title: 'Supprimer la conversation ?',
      body:
          'Elle disparaît de tes chats. Pour la retrouver, ouvre le chat une fois depuis le tournoi.',
      confirmLabel: 'Supprimer',
    );
    if (!ok) return;
    await _run(() => _api.hideTournamentChat(id));
  }

  Future<void> _clearTeam(String id) async {
    final ok = await confirmChatAction(
      context,
      title: 'Vider le chat ?',
      body: 'L’historique disparaît pour toi. Les autres membres le gardent.',
      confirmLabel: 'Vider',
    );
    if (!ok) return;
    await _run(() => _api.clearTeamChat(id));
  }

  Future<void> _hideTeam(String id) async {
    final ok = await confirmChatAction(
      context,
      title: 'Supprimer la conversation ?',
      body: 'Elle disparaît de tes chats. Réouvre-la depuis l’équipe.',
      confirmLabel: 'Supprimer',
    );
    if (!ok) return;
    await _run(() => _api.hideTeamChat(id));
  }

  Future<void> _clearInterTeam(String id) async {
    final ok = await confirmChatAction(
      context,
      title: 'Vider le chat ?',
      body: 'L’historique disparaît pour toi. Les autres capitaines le gardent.',
      confirmLabel: 'Vider',
    );
    if (!ok) return;
    await _run(() => _api.clearInterTeamChat(id));
  }

  Future<void> _hideInterTeam(String id) async {
    final ok = await confirmChatAction(
      context,
      title: 'Supprimer la conversation ?',
      body: 'Elle disparaît de tes chats. Réouvre-la depuis le tournoi.',
      confirmLabel: 'Supprimer',
    );
    if (!ok) return;
    await _run(() => _api.hideInterTeamChat(id));
  }

  @override
  Widget build(BuildContext context) {
    final list = RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: FutBoliaColors.danger),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(),
            ),
          if (!_loading && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucun message. Les chats privés de tes tournois et de tes amis s’affichent ici.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ..._items.map(
            (c) => ConversationTile(
              conversation: c,
              onTap: () => _open(c),
              onLongPress: () => _conversationActions(c),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return list;

    return Scaffold(
      backgroundColor: FutBoliaColors.surfaceDark,
      body: FbAtmosphere(
        safeArea: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  const Expanded(child: FbBrandHeader()),
                  Text(
                    'Chat',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: list),
          ],
        ),
      ),
    );
  }
}
