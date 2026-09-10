import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/domain/staff_label.dart';
import '../../invites/invite_friends_sheet.dart';
import '../../admin/admin_permissions.dart';
import '../../profile/presentation/public_profile_screen.dart';
import '../../private_chat/conversation_screen.dart';
import '../../profile/widgets/player_avatar.dart';

class PickupMatchDetailScreen extends StatefulWidget {
  const PickupMatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<PickupMatchDetailScreen> createState() =>
      _PickupMatchDetailScreenState();
}

class _PickupMatchDetailScreenState extends State<PickupMatchDetailScreen> {
  Map<String, dynamic>? _match;
  bool _loading = true;
  bool _joining = false;
  bool _leaving = false;
  bool _scoring = false;
  String? _error;
  final _homeScore = TextEditingController();
  final _awayScore = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _homeScore.dispose();
    _awayScore.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final match =
          await context.read<AuthSession>().api.getPickupMatch(widget.matchId);
      if (!mounted) return;
      setState(() {
        _match = match;
        if (match['homeScore'] != null) {
          _homeScore.text = '${match['homeScore']}';
        }
        if (match['awayScore'] != null) {
          _awayScore.text = '${match['awayScore']}';
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      await context.read<AuthSession>().api.joinPickupMatch(widget.matchId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inscription réussie')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _leave() async {
    setState(() => _leaving = true);
    try {
      await context.read<AuthSession>().api.leavePickupMatch(widget.matchId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu as quitté le match')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _submitScore() async {
    setState(() => _scoring = true);
    try {
      await context.read<AuthSession>().api.scorePickupMatch(widget.matchId, {
        'homeScore': int.tryParse(_homeScore.text.trim()) ?? 0,
        'awayScore': int.tryParse(_awayScore.text.trim()) ?? 0,
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Score enregistré')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _scoring = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le match ?'),
        content: const Text('Les joueurs inscrits seront notifiés via le statut.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: FutBoliaColors.danger),
            child: const Text('Annuler le match'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<AuthSession>().api.cancelPickupMatch(widget.matchId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match annulé')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce match ?'),
        content: const Text('Action définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: FutBoliaColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AuthSession>().api.deletePickupMatch(widget.matchId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _match == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Match introuvable')),
      );
    }

    final m = _match!;
    final isMember = m['isMember'] == true;
    final isHost = m['isHost'] == true;
    final staffManage = context.watch<AuthSession>().user?.hasPermission(
          AdminPermissions.manageTournaments,
        ) ??
        false;
    final canHost = isHost || staffManage;
    final isPrivate = m['visibility'] == 'private';
    final status = m['status']?.toString();
    final members = (m['members'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final home = members.where((e) => e['side'] == 'home').toList();
    final away = members.where((e) => e['side'] == 'away').toList();
    final unassigned = members
        .where((e) => e['side'] != 'home' && e['side'] != 'away')
        .toList();
    final canJoin = !isMember &&
        !isPrivate &&
        status == 'open';
    final canLeave = isMember &&
        !isHost &&
        status != 'finished' &&
        status != 'cancelled';
    final canScore = canHost &&
        status != 'cancelled';
    final canCancel = canHost &&
        status != 'cancelled';

    return Scaffold(
      appBar: AppBar(title: Text(m['location']?.toString() ?? 'Match')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FbBadge(label: FrLabels.matchStatus(status)),
              FbBadge(
                label: FrLabels.visibility(m['visibility']?.toString()),
                background: FutBoliaColors.badgeInfo,
                foreground: FutBoliaColors.inkDark,
              ),
              FbBadge(
                label: '${m['membersCount'] ?? 0} / ${m['capacity'] ?? '?'}',
                background: FutBoliaColors.badgeSoft,
                foreground: FutBoliaColors.inkDark,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Lieu : ${m['location']}'),
          Text('Date : ${_formatDate(m['scheduledAt'])}'),
          Text('Format : ${m['playersPerTeam']} vs ${m['playersPerTeam']}'),
          if (isMember)
            Text('Ton équipe : ${FrLabels.pickupSide(m['mySide']?.toString())}'),
          if (status == 'finished') ...[
            const SizedBox(height: 12),
            Text(
              'Score : ${m['homeScore']} — ${m['awayScore']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 24),
          if (!isMember && isPrivate && status == 'open')
            Text(
              'Match privé : tu dois recevoir une invitation de l’hôte.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FutBoliaColors.inkMuted,
                  ),
            ),
          if (canJoin) ...[
            FbButton(
              label: 'Rejoindre le match',
              loading: _joining,
              onPressed: _join,
            ),
            const SizedBox(height: 12),
          ],
          if (canHost && status == 'open') ...[
            FbButton(
              label: 'Inviter un joueur',
              variant: FbButtonVariant.secondary,
              onPressed: () => showInviteFriendsSheet(
                context,
                targetType: 'pickup_match',
                targetId: widget.matchId,
                title:
                    '${m['location']} · ${m['playersPerTeam']}v${m['playersPerTeam']}',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (canLeave) ...[
            FbButton(
              label: 'Quitter le match',
              variant: FbButtonVariant.secondary,
              loading: _leaving,
              onPressed: _leave,
            ),
            const SizedBox(height: 12),
          ],
          if (canScore) ...[
            const SizedBox(height: 8),
            Text(
              'Saisie du score',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _homeScore,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Équipe A'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _awayScore,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Équipe B'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FbButton(
              label: 'Valider le score',
              loading: _scoring,
              onPressed: _submitScore,
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: 12),
            FbButton(
              label: 'Annuler le match',
              variant: FbButtonVariant.secondary,
              onPressed: _cancel,
            ),
          ],
          if (staffManage) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: FutBoliaColors.danger,
              ),
              child: const Text('Supprimer le match'),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'Participants',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Les joueurs invités arrivent sans équipe. Glisse-les vers A ou B.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FutBoliaColors.inkMuted,
                ),
          ),
          if (canHost)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addParticipant,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Ajouter un joueur'),
              ),
            ),
          Text('Sans équipe', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _sideDrop(null, unassigned, canHost),
          const SizedBox(height: 20),
          Text('Équipe A', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _sideDrop('home', home, canHost),
          const SizedBox(height: 20),
          Text('Équipe B', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _sideDrop('away', away, canHost),
        ],
      ),
    );
  }

  Widget _sideDrop(
    String? side,
    List<Map<String, dynamic>> members,
    bool canHost,
  ) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => canHost,
      onAcceptWithDetails: (details) async {
        try {
          await context.read<AuthSession>().api.updatePickupMemberSide(
                widget.matchId,
                details.data,
                side,
              );
          await _load();
        } on ApiException catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
      builder: (context, pending, rejected) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: pending.isNotEmpty
                ? FutBoliaColors.lime.withValues(alpha: 0.35)
                : FutBoliaColors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FutBoliaColors.line),
          ),
          child: members.isEmpty
              ? Text(
                  side == null
                      ? 'Les joueurs sans équipe apparaissent ici'
                      : 'Dépose un joueur ici',
                  style: TextStyle(color: FutBoliaColors.inkMuted),
                )
              : Column(children: members.map(_memberTile).toList()),
        );
      },
    );
  }

  Widget _memberTile(Map<String, dynamic> m) {
    final user = m['user'] as Map<String, dynamic>? ?? {};
    final uid = user['id']?.toString();
    final pseudo = staffPseudoOf(user);
    final canHost = (_match?['isHost'] == true) ||
        (context.read<AuthSession>().user?.hasPermission(
              AdminPermissions.manageTournaments,
            ) ??
            false);
    final tile = ListTile(
      contentPadding: EdgeInsets.zero,
      leading: PlayerAvatar(
        userId: uid,
        avatarUrl: user['avatarUrl']?.toString(),
        radius: 18,
      ),
      title: Text(pseudo),
      onTap: () => _onMemberTap(
        uid,
        pseudo,
        canHost,
        m['side']?.toString(),
      ),
    );
    if (uid == null || !canHost) return tile;
    return LongPressDraggable<String>(
      data: uid,
      feedback: Material(
        elevation: 6,
        child: SizedBox(width: 240, child: tile),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );
  }

  Future<void> _onMemberTap(
    String? uid,
    String pseudo,
    bool canHost,
    String? side,
  ) async {
    if (uid == null) return;
    final me = context.read<AuthSession>().user?.id;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Voir le profil'),
              onTap: () {
                Navigator.pop(ctx);
                openPublicProfile(context, uid);
              },
            ),
            if (uid != me)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Message privé'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final conv = await context
                        .read<AuthSession>()
                        .api
                        .openConversation(uid);
                    if (!mounted) return;
                    openDirectChat(
                      context,
                      conversationId: conv['id'] as String,
                      friendName: pseudo,
                      friendId: uid,
                      canSend: conv['canSend'] != false,
                    );
                  } on ApiException catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.message)));
                  }
                },
              ),
            if (canHost) ...[
              if (side != 'home')
                ListTile(
                  leading: const Icon(Icons.arrow_forward),
                  title: const Text('Mettre en équipe A'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _moveSide(uid, 'home');
                  },
                ),
              if (side != 'away')
                ListTile(
                  leading: const Icon(Icons.arrow_forward),
                  title: const Text('Mettre en équipe B'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _moveSide(uid, 'away');
                  },
                ),
              if (side == 'home' || side == 'away')
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Remettre sans équipe'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _moveSide(uid, null);
                  },
                ),
            ],
            if (canHost && uid != _match?['createdById']?.toString())
              ListTile(
                leading: const Icon(Icons.logout, color: FutBoliaColors.danger),
                title: const Text('Retirer du match'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await context
                        .read<AuthSession>()
                        .api
                        .kickPickupMember(widget.matchId, uid);
                    await _load();
                  } on ApiException catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.message)));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveSide(String userId, String? side) async {
    try {
      await context.read<AuthSession>().api.updatePickupMemberSide(
            widget.matchId,
            userId,
            side,
          );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addParticipant() async {
    final q = TextEditingController();
    List<Map<String, dynamic>> results = [];
    var loading = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> search() async {
              if (q.text.trim().length < 2) return;
              setModal(() => loading = true);
              try {
                final rows = await context
                    .read<AuthSession>()
                    .api
                    .searchPlayers(q.text.trim());
                setModal(() {
                  results = rows;
                  loading = false;
                });
              } catch (_) {
                setModal(() => loading = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 420,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: q,
                          decoration: const InputDecoration(
                            labelText: 'Pseudo',
                          ),
                          onSubmitted: (_) => search(),
                        ),
                      ),
                      if (loading) const LinearProgressIndicator(),
                      Expanded(
                        child: ListView(
                          children: results.map((u) {
                            final id = u['id']?.toString();
                            return ListTile(
                              title: Text(staffPseudoOf(u)),
                              onTap: id == null
                                  ? null
                                  : () async {
                                      Navigator.pop(ctx);
                                      try {
                                        await context
                                            .read<AuthSession>()
                                            .api
                                            .addPickupMember(widget.matchId, {
                                          'userId': id,
                                        });
                                        await _load();
                                      } on ApiException catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text(e.message)),
                                        );
                                      }
                                    },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    q.dispose();
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Date inconnue';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return dt.toLocal().toString().substring(0, 16);
  }
}
