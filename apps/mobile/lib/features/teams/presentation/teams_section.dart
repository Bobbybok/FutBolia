import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/realtime/live_bindings.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/domain/staff_label.dart';
import '../../moderation/report_sheet.dart';
import '../../chat/presentation/team_chat_screen.dart';
import '../../profile/player_profile_labels.dart';
import '../../profile/presentation/public_profile_screen.dart';
import '../../private_chat/conversation_screen.dart';

class TeamsSection extends StatefulWidget {
  const TeamsSection({
    super.key,
    required this.tournamentId,
    required this.canManage,
    required this.members,
    this.isOrganizer = false,
    this.mode = 'classic',
  });

  final String tournamentId;
  final bool canManage;
  final List<Map<String, dynamic>> members;
  final bool isOrganizer;
  final String mode;

  @override
  State<TeamsSection> createState() => _TeamsSectionState();
}

class _TeamsSectionState extends State<TeamsSection> {
  List<Map<String, dynamic>> _teams = [];
  bool _loading = true;
  bool _creating = false;
  String? _error;
  final _teamName = TextEditingController();
  String? _pendingSelectorId;
  final _live = LiveBindings();

  @override
  void initState() {
    super.initState();
    _load();
    _live.listenTournament(widget.tournamentId, (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _live.dispose();
    _teamName.dispose();
    super.dispose();
  }

  String? _memberPseudo(String? userId) {
    if (userId == null) return null;
    for (final m in widget.members) {
      if (m['user']?['id']?.toString() == userId) {
        return staffPseudoOf(m['user']);
      }
    }
    return null;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final teams =
          await context.read<AuthSession>().api.listTeams(widget.tournamentId);
      if (!mounted) return;
      setState(() => _teams = teams);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _askClassicTeamName() async {
    _teamName.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          widget.isOrganizer ? 'Nouvelle équipe' : 'Créer mon équipe',
        ),
        content: TextField(
          controller: _teamName,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
          decoration: const InputDecoration(
            labelText: 'Nom de l’équipe',
            hintText: 'Ex. FC Quartier',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _teamName.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    _teamName.text = name;
    await _createTeam();
  }

  Future<void> _createTeam() async {
    final name = _teamName.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le nom d’équipe doit faire au moins 2 caractères'),
        ),
      );
      return;
    }
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final body = <String, dynamic>{'name': name};
      if (widget.mode == 'selection' && _pendingSelectorId != null) {
        body['selectorId'] = _pendingSelectorId;
      }
      await context.read<AuthSession>().api.createTeam(
            widget.tournamentId,
            body,
          );
      _teamName.clear();
      setState(() => _pendingSelectorId = null);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Équipe « $name » créée')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de créer l’équipe. Réessaie.')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _pickSelectorForCreate() async {
    final taken = _takenSelectorIds();
    final candidates = widget.members.where((m) {
      final id = m['user']?['id']?.toString();
      return id != null && !taken.contains(id);
    }).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun sélectionneur disponible (déjà assignés ou aucun participant)',
          ),
        ),
      );
      return;
    }
    final selected = await _pickTournamentMember(
      context: context,
      members: candidates,
      title: 'Sélectionneur de l’équipe',
      allowClear: true,
      clearLabel: 'Créer sans sélectionneur',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _pendingSelectorId = selected['_clear'] == true
          ? null
          : selected['user']?['id']?.toString();
    });
  }

  Set<String> _takenSelectorIds({String? exceptTeamId}) {
    final taken = <String>{};
    for (final t in _teams) {
      if (exceptTeamId != null && t['id']?.toString() == exceptTeamId) {
        continue;
      }
      final sid = t['selectorId']?.toString();
      if (sid != null && sid.isNotEmpty) taken.add(sid);
    }
    return taken;
  }

  Future<void> _openTeam(Map<String, dynamic> team) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeamDetailScreen(
          teamId: team['id'] as String,
          tournamentMembers: widget.members,
          isOrganizer: widget.isOrganizer,
          tournamentMode: widget.mode,
          takenSelectorIds: _takenSelectorIds(
            exceptTeamId: team['id']?.toString(),
          ),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Équipes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (widget.canManage && widget.mode != 'selection') ...[
          FbButton(
            label: widget.isOrganizer ? 'Créer une équipe' : 'Créer mon équipe',
            loading: _creating,
            onPressed: _askClassicTeamName,
          ),
          const SizedBox(height: 16),
        ],
        if (widget.isOrganizer && widget.mode == 'selection') ...[
          TextField(
            controller: _teamName,
            decoration: const InputDecoration(
              labelText: 'Nom de l’équipe (mode Sélection)',
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _pendingSelectorId == null
                  ? 'Sélectionneur : non assigné'
                  : 'Sélectionneur : ${_memberPseudo(_pendingSelectorId) ?? 'choisi'}',
            ),
            subtitle: const Text('Requis pour recruter via le Mercato'),
            trailing: TextButton(
              onPressed: _pickSelectorForCreate,
              child: Text(
                _pendingSelectorId == null ? 'Choisir' : 'Changer',
              ),
            ),
          ),
          FbButton(
            label: 'Créer l’équipe',
            loading: _creating,
            onPressed: _createTeam,
          ),
          const SizedBox(height: 16),
        ],
        if (!widget.isOrganizer && widget.mode == 'selection') ...[
          Text(
            'Mode Sélection : seul l’organisateur crée les équipes. Tu rejoins via le Mercato.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FutBoliaColors.inkMuted,
                ),
          ),
          const SizedBox(height: 16),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: FutBoliaColors.danger))
        else if (_teams.isEmpty)
          Text(
            'Aucune équipe pour le moment.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FutBoliaColors.inkMuted,
                ),
          )
        else
          ..._teams.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _openTeam(t),
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FutBoliaColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: FutBoliaColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['name']?.toString() ?? '',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          Text(
                              widget.mode == 'selection'
                                  ? '${t['membersCount'] ?? 0} joueur(s) · '
                                      '${t['selectorId'] == null ? 'Sans sélectionneur' : 'Sél. ${_memberPseudo(t['selectorId']?.toString()) ?? '—'}'}'
                                  : '${t['membersCount'] ?? 0}/${(t['startersMax'] ?? 0) + (t['substitutesMax'] ?? 0)} · '
                                      '${t['startersCount'] ?? 0}/${t['startersMax'] ?? '?'} tit.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      FbBadge(
                        label: FrLabels.teamStatus(t['status']?.toString()),
                      ),
                      if (t['isCaptain'] == true) ...[
                        const SizedBox(width: 8),
                        const FbBadge(label: 'Capitaine'),
                      ],
                      if (t['isSelector'] == true) ...[
                        const SizedBox(width: 8),
                        const FbBadge(label: 'Sélectionneur'),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({
    super.key,
    required this.teamId,
    required this.tournamentMembers,
    this.isOrganizer = false,
    this.tournamentMode = 'classic',
    this.takenSelectorIds = const {},
  });

  final String teamId;
  final List<Map<String, dynamic>> tournamentMembers;
  final bool isOrganizer;
  final String tournamentMode;
  final Set<String> takenSelectorIds;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  Map<String, dynamic>? _team;
  bool _loading = true;
  String? _error;
  final _live = LiveBindings();
  String? _liveTournamentId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final team = await context.read<AuthSession>().api.getTeam(widget.teamId);
      if (!mounted) return;
      setState(() => _team = team);
      final tournamentId = team['tournamentId']?.toString();
      if (tournamentId != null && tournamentId != _liveTournamentId) {
        _liveTournamentId = tournamentId;
        _live.listenTournament(tournamentId, (event) {
          if (!mounted) return;
          if (event['reason'] == 'team.deleted' &&
              event['teamId']?.toString() == widget.teamId) {
            Navigator.of(context).pop();
            return;
          }
          _load(silent: true);
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (silent) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _addMember({String? presetSlot}) async {
    final team = _team;
    if (team == null) return;

    final already = <String>{
      ...((team['starters'] as List?) ?? []).map((e) => e['userId'].toString()),
      ...((team['substitutes'] as List?) ?? [])
          .map((e) => e['userId'].toString()),
    };

    final candidates = widget.tournamentMembers
        .where((m) => !already.contains(m['user']?['id']?.toString()))
        .toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun participant disponible à ajouter')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              const ListTile(title: Text('Ajouter un joueur')),
              ...candidates.map(
                (m) => ListTile(
                  title: Text(staffPseudoOf(m['user'])),
                  subtitle: Text(FrLabels.memberRole(m['role']?.toString())),
                  onTap: () => Navigator.pop(context, m),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    var slot = presetSlot;
    if (slot == null) {
      slot = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Titulaire ou remplaçant ?'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'starter'),
              child: const Text('Titulaire'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'substitute'),
              child: const Text('Remplaçant'),
            ),
          ],
        ),
      );
      if (slot == null || !mounted) return;
    }

    final picked = await pickFifaPosition(context);
    if (!mounted) return;
    final position = picked == null || picked.isEmpty ? null : picked;

    try {
      await context.read<AuthSession>().api.addTeamMember(widget.teamId, {
        'userId': selected['user']['id'],
        'slot': slot,
        'position': ?position,
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _setCaptain(String userId) async {
    try {
      await context.read<AuthSession>().api.setTeamCaptain(widget.teamId, userId);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _remove(String userId) async {
    try {
      await context.read<AuthSession>().api.removeTeamMember(widget.teamId, userId);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String? _selectorPseudo(String? selectorId) {
    if (selectorId == null) return null;
    for (final m in widget.tournamentMembers) {
      if (m['user']?['id']?.toString() == selectorId) {
        return staffPseudoOf(m['user']);
      }
    }
    return null;
  }

  Future<void> _assignSelector() async {
    final currentSelector = _team?['selectorId']?.toString();
    final candidates = widget.tournamentMembers.where((m) {
      final id = m['user']?['id']?.toString();
      if (id == null) return false;
      if (id == currentSelector) return true;
      return !widget.takenSelectorIds.contains(id);
    }).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun participant disponible')),
      );
      return;
    }
    final selected = await _pickTournamentMember(
      context: context,
      members: candidates,
      title: 'Assigner un sélectionneur',
    );
    if (selected == null || !mounted) return;
    final userId = selected['user']?['id']?.toString();
    if (userId == null) return;
    try {
      await context.read<AuthSession>().api.assignTeamSelector(
            widget.teamId,
            userId,
          );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sélectionneur : ${staffPseudoOf(selected['user'])}',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _team == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Équipe introuvable')),
      );
    }

    final team = _team!;
    final canEditRoles = team['canManageRoster'] == true;
    final canManage = canEditRoles;
    final canTransferCaptain = team['canTransferCaptain'] == true ||
        team['isCaptain'] == true ||
        widget.isOrganizer;
    final starters = (team['starters'] as List?) ?? [];
    final substitutes = (team['substitutes'] as List?) ?? [];
    final startersMax = (team['startersMax'] as num?)?.toInt() ?? starters.length;
    final substitutesMax =
        (team['substitutesMax'] as num?)?.toInt() ?? startersMax;
    final status = team['status']?.toString();
    final selectorId = team['selectorId']?.toString();
    final isSelection = widget.tournamentMode == 'selection';
    final me = context.watch<AuthSession>().user?.id;
    final isCaptain = team['isCaptain'] == true || team['captainId'] == me;

    return Scaffold(
      appBar: AppBar(
        title: Text(team['name']?.toString() ?? 'Équipe'),
        actions: [
          IconButton(
            tooltip: 'Chat d’équipe',
            onPressed: () => openTeamChat(
              context,
              teamId: widget.teamId,
              teamName: team['name']?.toString() ?? 'Équipe',
              canClearForEveryone: widget.isOrganizer || isCaptain,
            ),
            icon: const Icon(Icons.chat_outlined),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _addMember,
              backgroundColor: FutBoliaColors.pitch,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text('Ajouter'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FbBadge(label: FrLabels.teamStatus(status)),
          if (widget.isOrganizer) ...[
            const SizedBox(height: 12),
            FbButton(
              label: 'Renommer l’équipe',
              variant: FbButtonVariant.secondary,
              onPressed: _renameTeam,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _deleteTeam,
              style: OutlinedButton.styleFrom(
                foregroundColor: FutBoliaColors.danger,
              ),
              child: const Text('Supprimer l’équipe'),
            ),
            const SizedBox(height: 8),
          ],
          if (canTransferCaptain) ...[
            const SizedBox(height: 8),
            FbButton(
              label: 'Transférer le capitaine',
              variant: FbButtonVariant.secondary,
              onPressed: _transferCaptain,
            ),
          ],
          if (isSelection) ...[
            const SizedBox(height: 16),
            Text(
              'Sélectionneur',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              selectorId == null
                  ? 'Aucun sélectionneur assigné'
                  : (_selectorPseudo(selectorId) ?? selectorId),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (widget.isOrganizer) ...[
              const SizedBox(height: 10),
              FbButton(
                label: selectorId == null
                    ? 'Assigner un sélectionneur'
                    : 'Changer le sélectionneur',
                onPressed: _assignSelector,
              ),
            ],
          ],
          const SizedBox(height: 16),
          if (widget.isOrganizer && status == 'complete') ...[
            FbButton(
              label: 'Valider l’effectif',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await context.read<AuthSession>().api.validateTeam(widget.teamId);
                  await _load();
                } on ApiException catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(content: Text(e.message)));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
          Text('Titulaires', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...starters.map((m) => _memberTile(m, canEditRoles, canTransferCaptain)),
          for (var i = starters.length; i < startersMax; i++)
            _emptySlot(
              'Titulaire ${i + 1}',
              canManage: canManage,
              slot: 'starter',
            ),
          const SizedBox(height: 20),
          Text('Remplaçants', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...substitutes.map((m) => _memberTile(m, canEditRoles, canTransferCaptain)),
          for (var i = substitutes.length; i < substitutesMax; i++)
            _emptySlot(
              'Remplaçant ${i + 1}',
              canManage: canManage,
              slot: 'substitute',
            ),
        ],
      ),
    );
  }

  Widget _emptySlot(
    String label, {
    required bool canManage,
    required String slot,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: canManage ? () => _addMember(presetSlot: slot) : null,
      leading: CircleAvatar(
        backgroundColor: FutBoliaColors.line.withValues(alpha: 0.45),
        child: const Icon(Icons.person_outline),
      ),
      title: const Text('Poste libre'),
      subtitle: Text(label),
      trailing: canManage ? const Icon(Icons.add) : null,
    );
  }

  Widget _memberTile(
    dynamic member,
    bool canManage, [
    bool canTransferCaptain = false,
  ]) {
    final map = Map<String, dynamic>.from(member as Map);
    final userId = map['userId']?.toString() ?? '';
    final isCaptain = map['isCaptain'] == true;
    final pos = PlayerProfileLabels.positionLong(map['position']?.toString());
    final slot = map['slot']?.toString();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: canManage
          ? () => _setPosition(map)
          : () => openPublicProfile(context, userId),
      title: Text(staffPseudoOf(map)),
      subtitle: Text(
        [
          FrLabels.teamSlot(slot),
          if (pos.isNotEmpty) pos else if (canManage) 'Appuie pour choisir le poste',
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCaptain) const FbBadge(label: 'Capitaine'),
          if (canManage)
            TextButton(
              onPressed: () => _setPosition(map),
              child: Text(pos.isEmpty ? 'Poste' : PlayerProfileLabels.position(map['position']?.toString())),
            ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  openPublicProfile(context, userId);
                case 'message':
                  _message(userId, staffPseudoOf(map));
                case 'report':
                  showReportSheet(
                    context,
                    type: 'user',
                    targetId: userId,
                    title: 'Signaler ${staffPseudoOf(map)}',
                  );
                case 'position':
                  _setPosition(map);
                case 'slot':
                  _toggleSlot(userId);
                case 'captain':
                  _setCaptain(userId);
                case 'remove':
                  _remove(userId);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'profile', child: Text('Voir le profil')),
              if (userId.isNotEmpty && userId != context.read<AuthSession>().user?.id)
                const PopupMenuItem(value: 'message', child: Text('Message')),
              if (userId.isNotEmpty)
                const PopupMenuItem(value: 'report', child: Text('Signaler')),
              if (canManage) ...[
                const PopupMenuItem(
                  value: 'position',
                  child: Text('Choisir le poste (GB, DC, BU…)'),
                ),
                PopupMenuItem(
                  value: 'slot',
                  child: Text(
                    slot == 'starter' ? 'Passer remplaçant' : 'Passer titulaire',
                  ),
                ),
                if (canTransferCaptain && !isCaptain)
                  const PopupMenuItem(
                    value: 'captain',
                    child: Text('Nommer capitaine'),
                  ),
                if (!isCaptain || widget.isOrganizer)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Retirer de l’équipe'),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _message(String userId, String name) async {
    try {
      final conv = await context.read<AuthSession>().api.openConversation(userId);
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

  Future<void> _toggleSlot(String userId) async {
    try {
      await context.read<AuthSession>().api.toggleTeamMemberSlot(
            widget.teamId,
            userId,
          );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _setPosition(Map<String, dynamic> member) async {
    final userId = member['userId']?.toString();
    if (userId == null) return;
    final picked = await pickFifaPosition(
      context,
      selected: member['position']?.toString(),
    );
    if (picked == null || !mounted) return;
    final position = picked.isEmpty ? null : picked;
    try {
      await context.read<AuthSession>().api.updateTeamMember(
            widget.teamId,
            userId,
            {'position': position},
          );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            position == null
                ? 'Poste retiré'
                : 'Poste : ${PlayerProfileLabels.positionLong(position)}',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _transferCaptain() async {
    final team = _team;
    if (team == null) return;
    final members = [
      ...((team['starters'] as List?) ?? []),
      ...((team['substitutes'] as List?) ?? []),
    ];
    final others = members
        .where((m) => m['isCaptain'] != true)
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun autre joueur dans l’équipe')),
      );
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('Nouveau capitaine')),
            ...others.map(
              (m) => ListTile(
                title: Text(staffPseudoOf(m)),
                onTap: () => Navigator.pop(ctx, m),
              ),
            ),
          ],
        ),
      ),
    );
    final userId = selected?['userId']?.toString();
    if (userId == null || !mounted) return;
    await _setCaptain(userId);
  }

  Future<void> _renameTeam() async {
    final current = _team?['name']?.toString() ?? '';
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom de l’équipe'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (name == null || name.length < 2 || !mounted) return;
    try {
      await context.read<AuthSession>().api.updateTeam(widget.teamId, {
        'name': name,
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteTeam() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette équipe ?'),
        content: const Text('Les joueurs redeviennent sans équipe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: FutBoliaColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthSession>().api.deleteTeam(widget.teamId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

Future<Map<String, dynamic>?> _pickTournamentMember({
  required BuildContext context,
  required List<Map<String, dynamic>> members,
  required String title,
  bool allowClear = false,
  String clearLabel = 'Aucun',
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: ListView(
          children: [
            ListTile(title: Text(title)),
            if (allowClear)
              ListTile(
                title: Text(clearLabel),
                leading: const Icon(Icons.clear),
                onTap: () => Navigator.pop(context, <String, dynamic>{
                  '_clear': true,
                }),
              ),
            ...members.map(
              (m) => ListTile(
                title: Text(staffPseudoOf(m['user'])),
                subtitle: Text(FrLabels.memberRole(m['role']?.toString())),
                onTap: () => Navigator.pop(context, m),
              ),
            ),
          ],
        ),
      );
    },
  );
}
