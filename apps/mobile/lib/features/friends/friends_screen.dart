import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';
import '../private_chat/conversation_screen.dart';
import '../private_chat/conversations_list_screen.dart';
import '../pickup_matches/presentation/pickup_match_detail_screen.dart';
import '../tournaments/presentation/tournament_detail_screen.dart';
import '../invites/invite_friend_to_event_sheet.dart';
import 'widgets/friend_tile.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _outgoing = [];
  List<Map<String, dynamic>> _eventInvites = [];
  List<Map<String, dynamic>> _results = [];

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final friends = await _api.listFriends();
      final requests = await _api.listFriendRequests();
      final invites = await _api.listEventInvites();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _incoming = _asMaps(requests['incoming']);
        _outgoing = _asMaps(requests['outgoing']);
        _eventInvites = invites;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Chargement impossible';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _asMaps(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _searchPlayers() async {
    final q = _search.text.trim();
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    try {
      final results = await _api.searchPlayers(q);
      if (!mounted) return;
      setState(() => _results = results);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _sendRequest(Map<String, dynamic> user) async {
    try {
      await _api.sendFriendRequest(userId: user['id'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande envoyée')),
      );
      _search.clear();
      setState(() => _results = []);
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _acceptInvite(String id) async {
    try {
      final invite = await _api.acceptEventInvite(id);
      await _reload();
      if (!mounted) return;
      final type = invite['targetType']?.toString();
      final targetId = invite['targetId']?.toString();
      if (type != null && targetId != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => type == 'tournament'
                ? TournamentDetailScreen(tournamentId: targetId)
                : PickupMatchDetailScreen(matchId: targetId),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _declineInvite(String id) async {
    try {
      await _api.declineEventInvite(id);
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _accept(String id) async {
    try {
      await _api.acceptFriendRequest(id);
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _decline(String id) async {
    try {
      await _api.declineFriendRequest(id);
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _unfriend(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer cet ami ?'),
        content: Text(staffPseudoOf(user)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.unfriend(user['id'] as String);
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _message(Map<String, dynamic> user) async {
    try {
      final conv = await _api.openConversation(user['id'] as String);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            conversationId: conv['id'] as String,
            friendName: staffPseudoOf(conv['friend'] ?? user),
            canSend: conv['canSend'] != false,
          ),
        ),
      );
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amis'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              text: (_incoming.isEmpty && _eventInvites.isEmpty)
                  ? 'Amis'
                  : 'Amis (${_incoming.length + _eventInvites.length})',
            ),
            const Tab(text: 'Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          RefreshIndicator(onRefresh: _reload, child: _friendsTab()),
          const ConversationsListScreen(embedded: true),
        ],
      ),
    );
  }

  Widget _friendsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Ajouter un joueur (pseudo)',
            suffixIcon: IconButton(
              onPressed: _searchPlayers,
              icon: const Icon(Icons.search),
            ),
          ),
          onSubmitted: (_) => _searchPlayers(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: FutBoliaColors.danger)),
        ],
        if (_loading) const LinearProgressIndicator(),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Résultats', style: Theme.of(context).textTheme.titleMedium),
          ..._results.map((user) {
            final status = user['friendship']?.toString() ?? 'none';
            return FriendTile(
              user: user,
              trailing: _searchAction(user, status),
            );
          }),
        ],
        if (_eventInvites.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Invitations tournoi / match',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ..._eventInvites.map((row) {
            final inviter =
                Map<String, dynamic>.from(row['inviter'] as Map? ?? {});
            final kind = row['targetType'] == 'tournament' ? 'Tournoi' : 'Match';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(row['targetLabel']?.toString() ?? kind),
              subtitle: Text(
                '$kind · invitation de ${staffPseudoOf(inviter)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Accepter',
                    onPressed: () => _acceptInvite(row['id'] as String),
                    icon: const Icon(Icons.check),
                    color: FutBoliaColors.success,
                  ),
                  IconButton(
                    tooltip: 'Refuser',
                    onPressed: () => _declineInvite(row['id'] as String),
                    icon: const Icon(Icons.close),
                    color: FutBoliaColors.danger,
                  ),
                ],
              ),
            );
          }),
        ],
        if (_incoming.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Demandes reçues', style: Theme.of(context).textTheme.titleMedium),
          ..._incoming.map((row) {
            final user = Map<String, dynamic>.from(row['user'] as Map? ?? {});
            return FriendTile(
              user: user,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Accepter',
                    onPressed: () => _accept(row['id'] as String),
                    icon: const Icon(Icons.check),
                    color: FutBoliaColors.success,
                  ),
                  IconButton(
                    tooltip: 'Refuser',
                    onPressed: () => _decline(row['id'] as String),
                    icon: const Icon(Icons.close),
                    color: FutBoliaColors.danger,
                  ),
                ],
              ),
            );
          }),
        ],
        if (_outgoing.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Demandes envoyées', style: Theme.of(context).textTheme.titleMedium),
          ..._outgoing.map((row) {
            final user = Map<String, dynamic>.from(row['user'] as Map? ?? {});
            return FriendTile(user: user, trailing: const Text('En attente'));
          }),
        ],
        const SizedBox(height: 16),
        Text('Mes amis', style: Theme.of(context).textTheme.titleMedium),
        if (!_loading && _friends.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Pas encore d’amis. Cherche un pseudo ci-dessus.'),
          ),
        ..._friends.map(
          (user) => FriendTile(
            user: user,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Inviter',
                  onPressed: () => showInviteFriendToEventSheet(
                    context,
                    friend: user,
                  ),
                  icon: const Icon(Icons.mail_outline),
                ),
                IconButton(
                  tooltip: 'Message',
                  onPressed: () => _message(user),
                  icon: const Icon(Icons.chat_bubble_outline),
                ),
                IconButton(
                  tooltip: 'Retirer',
                  onPressed: () => _unfriend(user),
                  icon: const Icon(Icons.person_remove_outlined),
                  color: FutBoliaColors.danger,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchAction(Map<String, dynamic> user, String status) {
    switch (status) {
      case 'friends':
        return TextButton(
          onPressed: () => _message(user),
          child: const Text('Message'),
        );
      case 'pending_sent':
        return const Text('Envoyée');
      case 'pending_received':
        return const Text('À accepter');
      default:
        return IconButton(
          tooltip: 'Ajouter',
          onPressed: () => _sendRequest(user),
          icon: const Icon(Icons.person_add_alt_1),
        );
    }
  }
}
