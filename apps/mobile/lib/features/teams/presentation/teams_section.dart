import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/domain/staff_label.dart';

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
  String? _error;
  final _teamName = TextEditingController();
  String? _pendingSelectorId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final teams =
          await context.read<AuthSession>().api.listTeams(widget.tournamentId);
      if (!mounted) return;
      setState(() => _teams = teams);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTeam() async {
    final name = _teamName.text.trim();
    if (name.length < 2) return;
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
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
        if (widget.canManage && widget.mode == 'classic') ...[
          TextField(
            controller: _teamName,
            decoration: const InputDecoration(labelText: 'Nom de la nouvelle équipe'),
          ),
          const SizedBox(height: 10),
          FbButton(label: 'Créer mon équipe', onPressed: _createTeam),
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
          FbButton(label: 'Créer l’équipe', onPressed: _createTeam),
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
                                  : '${t['membersCount'] ?? 0} joueur(s)',
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final team = await context.read<AuthSession>().api.getTeam(widget.teamId);
      if (!mounted) return;
      setState(() => _team = team);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMember() async {
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

    final slot = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Poste'),
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

    try {
      await context.read<AuthSession>().api.addTeamMember(widget.teamId, {
        'userId': selected['user']['id'],
        'slot': slot,
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
    final canManage = team['isCaptain'] == true ||
        team['isSelector'] == true ||
        widget.isOrganizer;
    final starters = (team['starters'] as List?) ?? [];
    final substitutes = (team['substitutes'] as List?) ?? [];
    final status = team['status']?.toString();
    final selectorId = team['selectorId']?.toString();
    final isSelection = widget.tournamentMode == 'selection';

    return Scaffold(
      appBar: AppBar(title: Text(team['name']?.toString() ?? 'Équipe')),
      floatingActionButton: canManage && status != 'validated'
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
          ...starters.map((m) => _memberTile(m, canManage && status != 'validated')),
          const SizedBox(height: 20),
          Text('Remplaçants', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (substitutes.isEmpty)
            Text(
              'Aucun remplaçant',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FutBoliaColors.inkMuted,
                  ),
            )
          else
            ...substitutes.map(
              (m) => _memberTile(m, canManage && status != 'validated'),
            ),
        ],
      ),
    );
  }

  Widget _memberTile(dynamic member, bool canManage) {
    final map = Map<String, dynamic>.from(member as Map);
    final userId = map['userId']?.toString() ?? '';
    final isCaptain = map['isCaptain'] == true;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(staffPseudoOf(map)),
      subtitle: Text(FrLabels.teamSlot(map['slot']?.toString())),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCaptain) const FbBadge(label: 'Capitaine'),
          if (canManage && !isCaptain) ...[
            IconButton(
              tooltip: 'Nommer capitaine',
              onPressed: () => _setCaptain(userId),
              icon: const Icon(Icons.star_outline),
            ),
            IconButton(
              tooltip: 'Retirer',
              onPressed: () => _remove(userId),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ],
      ),
    );
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
