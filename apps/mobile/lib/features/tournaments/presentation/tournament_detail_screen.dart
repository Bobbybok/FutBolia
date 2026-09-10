import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../auth/application/auth_session.dart';
import '../../invites/invite_friends_sheet.dart';
import '../../teams/presentation/teams_section.dart';
import '../../teams/presentation/tournament_roster_section.dart';
import '../../mercato/presentation/mercato_screen.dart';
import '../../matches/presentation/matches_screen.dart';
import '../../chat/presentation/tournament_chat_screen.dart';
import '../../admin/admin_permissions.dart';
import 'edit_tournament_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  Map<String, dynamic>? _tournament;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _joining = false;
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
      final api = context.read<AuthSession>().api;
      final tournament = await api.getTournament(widget.tournamentId);
      List<Map<String, dynamic>> members = [];
      try {
        members = await api.getTournamentMembers(widget.tournamentId);
      } catch (_) {
        // Private tournament members may be hidden until joined.
      }
      if (!mounted) return;
      setState(() {
        _tournament = tournament;
        _members = members;
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
      await context.read<AuthSession>().api.joinTournament(widget.tournamentId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inscription réussie')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _deleteTournament() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le tournoi ?'),
        content: const Text(
          'Cette action est définitive. Équipes, mercato et inscriptions seront effacés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
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

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthSession>().api.deleteTournament(widget.tournamentId);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Tournoi supprimé')),
      );
      navigator.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _tournament == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Tournoi introuvable')),
      );
    }

    final t = _tournament!;
    final user = context.watch<AuthSession>().user;
    final isMember = t['myRole'] != null;
    final isPrivate = t['visibility'] == 'private';
    final isOrganizer = t['isOrganizer'] == true ||
        t['myRole'] == 'organizer' ||
        t['createdById']?.toString() == user?.id;
    final isStaff = user?.isStaff ?? false;
    final canManage = t['canManage'] == true ||
        isOrganizer ||
        (user?.hasPermission(AdminPermissions.manageTournaments) ?? false);
    final canCreateTeam = t['canCreateTeam'] == true ||
        canManage ||
        (isMember && t['mode']?.toString() != 'selection');

    return Scaffold(
      appBar: AppBar(title: Text(t['name']?.toString() ?? 'Tournoi')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FbBadge(
                label: FrLabels.tournamentStatus(t['status']?.toString()),
              ),
              FbBadge(
                label: FrLabels.tournamentMode(t['mode']?.toString()),
                background: FutBoliaColors.badgeSoft,
                foreground: FutBoliaColors.inkDark,
              ),
              FbBadge(
                label: FrLabels.visibility(t['visibility']?.toString()),
                background: FutBoliaColors.badgeInfo,
                foreground: FutBoliaColors.inkDark,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            t['description']?.toString().isNotEmpty == true
                ? t['description'].toString()
                : 'Pas de description.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text('Lieu : ${t['location']}'),
          Text('Date : ${_formatDate(t['startsAt'])}'),
          Text('Équipes max : ${t['maxTeams']}'),
          Text('Titulaires / remplaçants : ${t['startersCount']} / ${t['startersCount']}'),
          Text('Participants : ${t['membersCount'] ?? _members.length}'),
          const SizedBox(height: 24),
          if (!isMember) ...[
            if (isPrivate)
              Text(
                'Tournoi privé : tu dois recevoir une invitation de l’organisateur.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FutBoliaColors.inkMuted,
                    ),
              )
            else
              FbButton(
                label: 'Rejoindre le tournoi',
                loading: _joining,
                onPressed: _join,
              ),
          ] else
            FbBadge(
              label:
                  'Membre · ${FrLabels.memberRole(t['myRole']?.toString())}',
              background: FutBoliaColors.lime,
            ),
          if (canManage) ...[
            const SizedBox(height: 16),
            FbButton(
              label: 'Inviter un joueur',
              variant: FbButtonVariant.secondary,
              onPressed: () => showInviteFriendsSheet(
                context,
                targetType: 'tournament',
                targetId: widget.tournamentId,
                title: t['name']?.toString() ?? 'Tournoi',
              ),
            ),
          ],
          if (isMember || canManage) ...[
            const SizedBox(height: 28),
            TeamsSection(
              tournamentId: widget.tournamentId,
              canManage: canCreateTeam,
              members: _members,
              isOrganizer: canManage,
              mode: t['mode']?.toString() ?? 'classic',
            ),
          ],
          if (isMember || canManage) ...[
            const SizedBox(height: 28),
            FbButton(
              label: 'Matchs & classement',
              variant: FbButtonVariant.secondary,
              onPressed: () async {
                final navigator = Navigator.of(context);
                await navigator.push(
                  MaterialPageRoute(
                    builder: (_) => MatchesScreen(
                      tournamentId: widget.tournamentId,
                      isOrganizer: canManage,
                    ),
                  ),
                );
                if (mounted) _load();
              },
            ),
          ],
          if (isMember || isStaff) ...[
            SizedBox(height: isMember ? 12 : 28),
            FbButton(
              label: 'Chat privé du tournoi',
              variant: FbButtonVariant.secondary,
              onPressed: () {
                openTournamentChat(
                  context,
                  tournamentId: widget.tournamentId,
                  tournamentName: t['name']?.toString() ?? 'Tournoi',
                  isOrganizer: isOrganizer,
                  canClearForEveryone: isOrganizer,
                  canSend: isMember,
                  restoreInInbox: true,
                );
              },
            ),
          ],
          if (isMember || canManage) ...[
            const SizedBox(height: 16),
            if (t['mode'] == 'selection') ...[
              FbButton(
                label: 'Ouvrir le Mercato',
                onPressed: () async {
                  final api = context.read<AuthSession>().api;
                  final me = context.read<AuthSession>().user!.id;
                  final role = t['myRole']?.toString();
                  final navigator = Navigator.of(context);
                  final teams = await api.listTeams(widget.tournamentId);
                  if (!mounted) return;
                  Map<String, dynamic>? mySelectorTeam;
                  final offerTeams = <Map<String, dynamic>>[];
                  for (final team in teams) {
                    final isMine =
                        team['selectorId'] == me || team['isSelector'] == true;
                    if (isMine) {
                      mySelectorTeam ??= team;
                      offerTeams.add(team);
                    } else if (role == 'organizer' || canManage) {
                      offerTeams.add(team);
                    }
                  }
                  await navigator.push(
                    MaterialPageRoute(
                      builder: (_) => MercatoScreen(
                        tournamentId: widget.tournamentId,
                        canSendOffers:
                            mySelectorTeam != null || canManage,
                        selectorTeamId: mySelectorTeam?['id'] as String?,
                        offerTeams: offerTeams,
                      ),
                    ),
                  );
                  if (mounted) _load();
                },
              ),
              const SizedBox(height: 16),
            ],
            TournamentRosterSection(
              tournamentId: widget.tournamentId,
              members: _members,
              canManage: canManage,
              createdById: t['createdById']?.toString(),
              onChanged: _load,
            ),
          ],
          if (isMember && t['createdById']?.toString() != user?.id) ...[
            const SizedBox(height: 20),
            FbButton(
              label: 'Quitter le tournoi',
              variant: FbButtonVariant.secondary,
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await context
                      .read<AuthSession>()
                      .api
                      .leaveTournament(widget.tournamentId);
                  if (!mounted) return;
                  navigator.pop();
                } on ApiException catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(content: Text(e.message)));
                }
              },
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 36),
            FbButton(
              label: 'Modifier le tournoi',
              variant: FbButtonVariant.secondary,
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EditTournamentScreen(tournament: t),
                  ),
                );
                if (ok == true && mounted) _load();
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _deleteTournament,
              style: OutlinedButton.styleFrom(
                foregroundColor: FutBoliaColors.danger,
                side: const BorderSide(color: FutBoliaColors.danger),
              ),
              child: const Text('Supprimer le tournoi'),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic value) {
    final dt = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
