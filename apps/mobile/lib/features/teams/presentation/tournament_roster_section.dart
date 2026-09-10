import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/domain/staff_label.dart';
import '../../chat/presentation/team_chat_screen.dart';
import '../../moderation/report_sheet.dart';
import '../../private_chat/conversation_screen.dart';
import '../../profile/player_profile_labels.dart';
import '../../profile/presentation/public_profile_screen.dart';
import '../../profile/widgets/player_avatar.dart';

class TournamentRosterSection extends StatefulWidget {
  const TournamentRosterSection({
    super.key,
    required this.tournamentId,
    required this.members,
    required this.canManage,
    required this.createdById,
    this.onChanged,
  });

  final String tournamentId;
  final List<Map<String, dynamic>> members;
  final bool canManage;
  final String? createdById;
  final VoidCallback? onChanged;

  @override
  State<TournamentRosterSection> createState() =>
      _TournamentRosterSectionState();
}

class _TournamentRosterSectionState extends State<TournamentRosterSection> {
  List<Map<String, dynamic>> _teams = [];
  bool _loading = true;

  ApiClient get _api => context.read<AuthSession>().api;
  String? get _me => context.read<AuthSession>().user?.id;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void didUpdateWidget(covariant TournamentRosterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.members != widget.members) {
      _loadTeams();
    }
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await _api.listTeams(widget.tournamentId);
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _loading = false;
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    await _loadTeams();
    widget.onChanged?.call();
  }

  List<Map<String, dynamic>> get _unassigned {
    return widget.members.where((m) {
      final teamId = m['teamId']?.toString();
      return teamId == null || teamId.isEmpty;
    }).toList();
  }

  bool _canDrag(Map<String, dynamic> member) {
    if (widget.canManage) return true;
    final uid = userIdOf(member);
    for (final team in _teams) {
      if (team['captainId']?.toString() == _me &&
          team['status']?.toString() != 'validated' &&
          (member['teamId']?.toString() == team['id']?.toString() ||
              member['teamId'] == null)) {
        if (member['teamId'] == null || uid != null) return true;
      }
    }
    return false;
  }

  Future<void> _assign(String userId, String? teamId) async {
    try {
      await _api.assignTournamentTeam(widget.tournamentId, {
        'userId': userId,
        'teamId': teamId,
      });
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openMember(Map<String, dynamic> member) async {
    final uid = userIdOf(member);
    if (uid == null) return;
    final pseudo = staffPseudoOf(member['user'] ?? member);
    final isCreator = uid == widget.createdById;
    final canKick = widget.canManage && !isCreator;
    final myCaptainTeamIds = _teams
        .where((t) =>
            t['captainId']?.toString() == _me &&
            t['status']?.toString() != 'validated')
        .map((t) => t['id']?.toString())
        .whereType<String>()
        .toSet();
    final memberTeamId = member['teamId']?.toString();
    final canUnassign = widget.canManage ||
        (memberTeamId != null && myCaptainTeamIds.contains(memberTeamId));
    final canSetPosition = memberTeamId != null &&
        (widget.canManage ||
            myCaptainTeamIds.contains(memberTeamId) ||
            _teams.any((t) =>
                t['id']?.toString() == memberTeamId &&
                (t['selectorId']?.toString() == _me ||
                    t['isSelector'] == true)));
    final canAssignToMine = myCaptainTeamIds.isNotEmpty &&
        (memberTeamId == null || memberTeamId.isEmpty);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: PlayerAvatar(
                  userId: uid,
                  avatarUrl: (member['user'] as Map?)?['avatarUrl']?.toString(),
                  radius: 20,
                ),
                title: Text(pseudo),
                subtitle: Text([
                  FrLabels.memberRole(member['role']?.toString()),
                  if (member['teamName'] != null) member['teamName'].toString(),
                  if (member['isCaptain'] == true) 'Capitaine',
                  if (member['position'] != null)
                    PlayerProfileLabels.position(member['position']?.toString()),
                ].where((e) => e.toString().isNotEmpty).join(' · ')),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Voir le profil'),
                onTap: () {
                  Navigator.pop(ctx);
                  openPublicProfile(context, uid);
                },
              ),
              if (uid != _me)
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text('Message privé'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _openChat(uid, pseudo);
                  },
                ),
              if (canSetPosition)
                ListTile(
                  leading: const Icon(Icons.sports_soccer_outlined),
                  title: const Text('Choisir le poste (GB, DC, BU…)'),
                  subtitle: Text(
                    member['position'] == null
                        ? 'Aucun poste attribué'
                        : PlayerProfileLabels.positionLong(
                            member['position']?.toString(),
                          ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _setMemberPosition(member);
                  },
                ),
              if (widget.canManage) ...[
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Choisir une équipe'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickTeamFor(uid);
                  },
                ),
              ] else if (canAssignToMine)
                ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: const Text('Ajouter à mon équipe'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final teamId = myCaptainTeamIds.first;
                    await _assign(uid, teamId);
                  },
                ),
              if (canUnassign && memberTeamId != null)
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined),
                  title: const Text('Retirer de l’équipe'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _assign(uid, null);
                  },
                ),
              if (canKick)
                ListTile(
                  leading: const Icon(Icons.logout, color: FutBoliaColors.danger),
                  title: const Text('Retirer du tournoi'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _kick(uid, pseudo);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Signaler'),
                onTap: () {
                  Navigator.pop(ctx);
                  showReportSheet(
                    context,
                    type: 'user',
                    targetId: uid,
                    title: 'Signaler $pseudo',
                  );
                },
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Future<void> _setMemberPosition(Map<String, dynamic> member) async {
    final uid = userIdOf(member);
    final teamId = member['teamId']?.toString();
    if (uid == null || teamId == null || teamId.isEmpty) return;
    final picked = await pickFifaPosition(
      context,
      selected: member['position']?.toString(),
    );
    if (picked == null || !mounted) return;
    try {
      await _api.updateTeamMember(teamId, uid, {
        'position': picked.isEmpty ? null : picked,
      });
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            picked.isEmpty
                ? 'Poste retiré'
                : 'Poste : ${PlayerProfileLabels.positionLong(picked)}',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openChat(String userId, String name) async {
    try {
      final conv = await _api.openConversation(userId);
      if (!mounted) return;
      openDirectChat(
        context,
        conversationId: conv['id'] as String,
        friendName: name,
        friendId: userId,
        canSend: conv['canSend'] != false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickTeamFor(String userId) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            children: [
              const ListTile(title: Text('Affecter à une équipe')),
              ListTile(
                title: const Text('Sans équipe'),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              ..._teams.map(
                (t) => ListTile(
                  title: Text(t['name']?.toString() ?? 'Équipe'),
                  subtitle: Text(
                    '${t['membersCount'] ?? 0} joueur(s) · '
                    '${t['startersCount'] ?? 0}/${t['startersMax'] ?? '?'} tit.',
                  ),
                  onTap: () => Navigator.pop(ctx, t['id']?.toString()),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    await _assign(userId, selected.isEmpty ? null : selected);
  }

  Future<void> _kick(String userId, String pseudo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer $pseudo ?'),
        content: const Text('Il quitte le tournoi et son équipe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: FutBoliaColors.danger),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.kickTournamentMember(widget.tournamentId, userId);
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
              final query = q.text.trim();
              if (query.length < 2) return;
              setModal(() => loading = true);
              try {
                final rows = await _api.searchPlayers(query);
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
                  height: MediaQuery.of(ctx).size.height * 0.65,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: q,
                          decoration: const InputDecoration(
                            labelText: 'Pseudo du joueur',
                            suffixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => search(),
                        ),
                      ),
                      if (loading) const LinearProgressIndicator(),
                      Expanded(
                        child: ListView(
                          children: results.map((u) {
                            final id = u['id']?.toString();
                            final already = widget.members.any(
                              (m) => userIdOf(m) == id,
                            );
                            return ListTile(
                              title: Text(staffPseudoOf(u)),
                              subtitle: already
                                  ? const Text('Déjà inscrit')
                                  : null,
                              enabled: !already && id != null,
                              onTap: already || id == null
                                  ? null
                                  : () async {
                                      Navigator.pop(ctx);
                                      try {
                                        await _api.addTournamentMember(
                                          widget.tournamentId,
                                          id,
                                        );
                                        await _reload();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Participants',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (widget.canManage)
              TextButton.icon(
                onPressed: _addParticipant,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Ajouter'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Glisse un joueur dans une équipe, ou appuie pour le profil / le chat.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: FutBoliaColors.inkMuted,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _column(
                title: 'Sans équipe',
                subtitle: '${_unassigned.length}',
                members: _unassigned,
                teamId: null,
                acceptDrop: widget.canManage ||
                    _teams.any((t) =>
                        t['captainId']?.toString() == _me &&
                        t['status']?.toString() != 'validated'),
              ),
              ..._teams.map((team) {
                final id = team['id']?.toString();
                final members = widget.members
                    .where((m) => m['teamId']?.toString() == id)
                    .toList();
                final isMyCaptain = team['captainId']?.toString() == _me &&
                    team['status']?.toString() != 'validated';
                return _column(
                  title: team['name']?.toString() ?? 'Équipe',
                  subtitle:
                      '${team['startersCount'] ?? 0}/${team['startersMax'] ?? '?'} tit. · '
                      '${team['substitutesCount'] ?? 0}/${team['substitutesMax'] ?? '?'} remp.',
                  members: members,
                  teamId: id,
                  team: team,
                  acceptDrop: widget.canManage || isMyCaptain,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _column({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> members,
    required String? teamId,
    Map<String, dynamic>? team,
    required bool acceptDrop,
  }) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FutBoliaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FutBoliaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (teamId != null)
                IconButton(
                  tooltip: 'Chat d’équipe',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => openTeamChat(
                    context,
                    teamId: teamId,
                    teamName: title,
                    canClearForEveryone: widget.canManage ||
                        team?['captainId']?.toString() == _me,
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                ),
            ],
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FutBoliaColors.inkMuted,
                ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DragTarget<String>(
              onWillAcceptWithDetails: (_) => acceptDrop,
              onAcceptWithDetails: (details) {
                if (!acceptDrop) return;
                _assign(details.data, teamId);
              },
              builder: (context, pending, rejected) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: pending.isNotEmpty
                        ? FutBoliaColors.lime.withValues(alpha: 0.35)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: members.isEmpty
                      ? Center(
                          child: Text(
                            'Dépose ici',
                            style: TextStyle(color: FutBoliaColors.inkMuted),
                          ),
                        )
                      : ListView(
                          children: members.map(_chip).toList(),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(Map<String, dynamic> member) {
    final uid = userIdOf(member);
    final pseudo = staffPseudoOf(member['user'] ?? member);
    final pos = PlayerProfileLabels.position(member['position']?.toString());
    final child = Material(
      color: FutBoliaColors.surfaceRaisedDark,
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: PlayerAvatar(
          userId: uid,
          avatarUrl: (member['user'] as Map?)?['avatarUrl']?.toString(),
          radius: 14,
        ),
        title: Text(pseudo, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (member['isCaptain'] == true) 'C',
            FrLabels.teamSlot(member['slot']?.toString()),
            if (pos.isNotEmpty) pos,
          ].where((e) => e.toString().isNotEmpty).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _openMember(member),
      ),
    );
    if (uid == null || !_canDrag(member)) return child;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LongPressDraggable<String>(
        data: uid,
        feedback: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 200, child: child),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: child),
        child: child,
      ),
    );
  }
}
