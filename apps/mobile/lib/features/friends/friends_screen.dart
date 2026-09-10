import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/realtime/socket_service.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';
import '../moderation/report_sheet.dart';
import '../private_chat/conversation_screen.dart';
import '../pickup_matches/presentation/pickup_match_detail_screen.dart';
import '../tournaments/presentation/tournament_detail_screen.dart';
import '../invites/invite_friend_to_event_sheet.dart';
import '../profile/presentation/public_profile_screen.dart';
import 'widgets/friend_tile.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _outgoing = [];
  List<Map<String, dynamic>> _eventInvites = [];
  List<Map<String, dynamic>> _results = [];
  final _subs = <StreamSubscription>[];

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  bool get wantKeepAlive => widget.embedded;

  @override
  void initState() {
    super.initState();
    _reload();
    final socket = SocketService.instance;
    _subs.add(socket.onFriendRequest.listen((_) => _reload(silent: true)));
    _subs.add(socket.onFriendAccepted.listen((_) => _reload(silent: true)));
    _subs.add(socket.onEventInvite.listen((_) => _reload(silent: true)));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
      await openDirectChat(
        context,
        conversationId: conv['id'] as String,
        friendName: staffPseudoOf(conv['friend'] ?? user),
        friendId: userIdOf(conv['friend'] ?? user),
        canSend: conv['canSend'] != false,
      );
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _report(Map<String, dynamic> user) async {
    final id = userIdOf(user);
    if (id == null) return;
    await showReportSheet(
      context,
      type: 'user',
      targetId: id,
      title: 'Signaler ${staffPseudoOf(user)}',
    );
  }

  void _openProfile(Map<String, dynamic> user) {
    openPublicProfile(context, userIdOf(user));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pending = _incoming.length + _eventInvites.length;
    final body = RefreshIndicator(onRefresh: _reload, child: _friendsTab());
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(pending == 0 ? 'Amis' : 'Amis ($pending)'),
      ),
      body: body,
    );
  }

  Widget _friendsTab() {
    TextStyle sectionStyle(BuildContext context) =>
        Theme.of(context).textTheme.titleMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _search,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ajouter un joueur (pseudo)',
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.35),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: FutBoliaColors.lime),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: FutBoliaColors.lime, width: 2),
            ),
            suffixIcon: IconButton(
              onPressed: _searchPlayers,
              icon: const Icon(Icons.search, color: Colors.white),
            ),
          ),
          onSubmitted: (_) => _searchPlayers(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: FutBoliaColors.danger)),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Résultats', style: sectionStyle(context)),
          const SizedBox(height: 8),
          ..._results.map((user) {
            final status = user['friendship']?.toString() ?? 'none';
            return FriendTile(
              user: user,
              onTap: () => _openProfile(user),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Signaler',
                    onPressed: () => _report(user),
                    icon: const Icon(Icons.flag_outlined),
                  ),
                  _searchAction(user, status),
                ],
              ),
            );
          }),
        ],
        if (_eventInvites.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Invitations tournoi / match', style: sectionStyle(context)),
          const SizedBox(height: 8),
          ..._eventInvites.map((row) {
            final inviter =
                Map<String, dynamic>.from(row['inviter'] as Map? ?? {});
            final kind = row['targetType'] == 'tournament' ? 'Tournoi' : 'Match';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: FutBoliaColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  title: Text(
                    row['targetLabel']?.toString() ?? kind,
                    style: const TextStyle(
                      color: FutBoliaColors.inkDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '$kind · invitation de ${staffPseudoOf(inviter)}',
                    style: const TextStyle(color: FutBoliaColors.inkMuted),
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
                ),
              ),
            );
          }),
        ],
        if (_incoming.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Demandes reçues', style: sectionStyle(context)),
          const SizedBox(height: 8),
          ..._incoming.map((row) {
            final user = Map<String, dynamic>.from(row['user'] as Map? ?? {});
            return FriendTile(
              user: user,
              onTap: () => _openProfile(user),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Signaler',
                    onPressed: () => _report(user),
                    icon: const Icon(Icons.flag_outlined),
                  ),
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
          Text('Demandes envoyées', style: sectionStyle(context)),
          const SizedBox(height: 8),
          ..._outgoing.map((row) {
            final user = Map<String, dynamic>.from(row['user'] as Map? ?? {});
            return FriendTile(
              user: user,
              onTap: () => _openProfile(user),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Signaler',
                    onPressed: () => _report(user),
                    icon: const Icon(Icons.flag_outlined),
                  ),
                  const Text(
                    'En attente',
                    style: TextStyle(color: FutBoliaColors.inkMuted),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 16),
        Text('Mes amis', style: sectionStyle(context)),
        const SizedBox(height: 8),
        if (!_loading && _friends.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Pas encore d’amis. Cherche un pseudo ci-dessus.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ..._friends.map(
          (user) => FriendTile(
            user: user,
            onTap: () => _openProfile(user),
            onReport: () => _report(user),
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
                  tooltip: 'Signaler',
                  onPressed: () => _report(user),
                  icon: const Icon(Icons.flag_outlined),
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
