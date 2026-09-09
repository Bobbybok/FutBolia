import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/domain/staff_label.dart';
import '../../invites/invite_friends_sheet.dart';
import '../../teams/presentation/teams_section.dart';
import '../../mercato/presentation/mercato_screen.dart';
import '../../matches/presentation/matches_screen.dart';
import '../../chat/presentation/tournament_chat_screen.dart';
import '../../moderation/report_sheet.dart';
import '../../profile/presentation/public_profile_screen.dart';

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
    final isMember = t['myRole'] != null;
    final isPrivate = t['visibility'] == 'private';
    final isOrganizer = t['myRole'] == 'organizer';
    final isStaff = context.watch<AuthSession>().user?.isStaff ?? false;

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
                background: const Color(0xFFE8F5E9),
              ),
              FbBadge(
                label: FrLabels.visibility(t['visibility']?.toString()),
                background: const Color(0xFFE3F2FD),
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
          Text('Titulaires / remplaçants : ${t['startersCount']} / ${t['substitutesCount']}'),
          Text('Participants : ${t['membersCount'] ?? _members.length}'),
          const SizedBox(height: 24),
          if (!isMember) ...[
            if (isPrivate)
              Text(
                'Tournoi privé : tu dois recevoir une invitation de l’organisateur (onglet Amis).',
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
          ] else ...[
            FbBadge(
              label:
                  'Membre · ${FrLabels.memberRole(t['myRole']?.toString())}',
              background: FutBoliaColors.lime,
            ),
            if (isPrivate && isOrganizer) ...[
              const SizedBox(height: 16),
              FbButton(
                label: 'Inviter des amis',
                variant: FbButtonVariant.secondary,
                onPressed: () => showInviteFriendsSheet(
                  context,
                  targetType: 'tournament',
                  targetId: widget.tournamentId,
                  title: t['name']?.toString() ?? 'Tournoi',
                ),
              ),
            ],
          ],
          if (isMember) ...[
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
                      isOrganizer: t['myRole'] == 'organizer',
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
          if (isMember) ...[
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
                    } else if (role == 'organizer') {
                      offerTeams.add(team);
                    }
                  }
                  await navigator.push(
                    MaterialPageRoute(
                      builder: (_) => MercatoScreen(
                        tournamentId: widget.tournamentId,
                        canSendOffers:
                            mySelectorTeam != null || role == 'organizer',
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
            TeamsSection(
              tournamentId: widget.tournamentId,
              canManage: true,
              members: _members,
              isOrganizer: t['myRole'] == 'organizer',
              mode: t['mode']?.toString() ?? 'classic',
            ),
          ],
          const SizedBox(height: 28),
          Text('Participants', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_members.isEmpty)
            Text(
              'Aucun participant visible.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FutBoliaColors.inkMuted,
                  ),
            )
          else
            ..._members.map(
              (m) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(staffPseudoOf(m['user'])),
                subtitle: Text(FrLabels.memberRole(m['role']?.toString())),
                trailing: IconButton(
                  tooltip: 'Signaler',
                  onPressed: () {
                    final id = userIdOf(m);
                    if (id == null) return;
                    showReportSheet(
                      context,
                      type: 'user',
                      targetId: id,
                      title: 'Signaler ${staffPseudoOf(m['user'])}',
                    );
                  },
                  icon: const Icon(Icons.flag_outlined),
                ),
              ),
            ),
          if (t['myRole'] == 'organizer') ...[
            const SizedBox(height: 36),
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
