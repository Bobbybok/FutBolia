import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../../core/network/api_client.dart';
import '../../../core/realtime/live_bindings.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({
    super.key,
    required this.tournamentId,
    required this.isOrganizer,
  });

  final String tournamentId;
  final bool isOrganizer;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _standings = [];
  List<Map<String, dynamic>> _teams = [];
  bool _loading = true;
  String? _error;
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
      final api = context.read<AuthSession>().api;
      final matches = await api.listMatches(widget.tournamentId);
      final standings = await api.getStandings(widget.tournamentId);
      final teams = await api.listTeams(widget.tournamentId);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _standings = standings;
        _teams = teams;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Générer le calendrier ?'),
        content: const Text(
          'Crée un match pour chaque paire d’équipes manquante (round-robin).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Générer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final res = await context
          .read<AuthSession>()
          .api
          .generateRoundRobin(widget.tournamentId);
      await _load();
      if (!mounted) return;
      final count = res['createdCount'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count match(s) créé(s)')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _createMatch() async {
    if (_teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il faut au moins 2 équipes')),
      );
      return;
    }
    String? homeId = _teams.first['id']?.toString();
    String? awayId = _teams.length > 1 ? _teams[1]['id']?.toString() : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Nouveau match'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: homeId,
                    decoration: const InputDecoration(labelText: 'Équipe domicile'),
                    items: _teams
                        .map(
                          (t) => DropdownMenuItem(
                            value: t['id']?.toString(),
                            child: Text(t['name']?.toString() ?? 'Équipe'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => homeId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: awayId,
                    decoration: const InputDecoration(labelText: 'Équipe extérieur'),
                    items: _teams
                        .map(
                          (t) => DropdownMenuItem(
                            value: t['id']?.toString(),
                            child: Text(t['name']?.toString() ?? 'Équipe'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => awayId = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || homeId == null || awayId == null || !mounted) {
      return;
    }
    try {
      await context.read<AuthSession>().api.createMatch(widget.tournamentId, {
        'homeTeamId': homeId,
        'awayTeamId': awayId,
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _scoreMatch(Map<String, dynamic> match) async {
    final homeCtrl = TextEditingController(
      text: match['homeScore']?.toString() ?? '',
    );
    final awayCtrl = TextEditingController(
      text: match['awayScore']?.toString() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${match['homeTeamName'] ?? 'Domicile'} — ${match['awayTeamName'] ?? 'Extérieur'}',
        ),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: homeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: match['homeTeamName']?.toString() ?? 'Domicile',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('–'),
            ),
            Expanded(
              child: TextField(
                controller: awayCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: match['awayTeamName']?.toString() ?? 'Extérieur',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final home = int.tryParse(homeCtrl.text.trim());
    final away = int.tryParse(awayCtrl.text.trim());
    if (home == null || away == null || home < 0 || away < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scores invalides')),
      );
      return;
    }
    try {
      await context.read<AuthSession>().api.updateMatch(
        match['id'].toString(),
        {
          'homeScore': home,
          'awayScore': away,
          'status': 'finished',
        },
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _cancelOrDelete(Map<String, dynamic> match) async {
    final status = match['status']?.toString();
    final isFinished = status == 'finished';
    final label = isFinished ? 'Annuler ce match ?' : 'Supprimer ce match ?';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: FutBoliaColors.danger),
            child: Text(isFinished ? 'Annuler le match' : 'Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = context.read<AuthSession>().api;
      final id = match['id'].toString();
      if (isFinished || status == 'cancelled') {
        await api.cancelMatch(id);
      } else {
        await api.deleteMatch(id);
      }
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matchs & classement')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (widget.isOrganizer) ...[
                        FbButton(
                          label: 'Générer le calendrier',
                          onPressed: _generate,
                        ),
                        const SizedBox(height: 10),
                        FbButton(
                          label: 'Créer un match',
                          variant: FbButtonVariant.secondary,
                          onPressed: _createMatch,
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        'Classement',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (_standings.isEmpty)
                        Text(
                          'Aucun classement pour le moment.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: FutBoliaColors.inkMuted,
                              ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('#')),
                              DataColumn(label: Text('Équipe')),
                              DataColumn(label: Text('Pts')),
                              DataColumn(label: Text('J')),
                              DataColumn(label: Text('Diff')),
                              DataColumn(label: Text('BP')),
                            ],
                            rows: _standings
                                .map(
                                  (r) => DataRow(
                                    cells: [
                                      DataCell(Text('${r['rank']}')),
                                      DataCell(
                                        Text(r['teamName']?.toString() ?? ''),
                                      ),
                                      DataCell(Text('${r['points']}')),
                                      DataCell(Text('${r['played']}')),
                                      DataCell(Text('${r['goalDiff']}')),
                                      DataCell(Text('${r['goalsFor']}')),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 28),
                      Text(
                        'Matchs',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (_matches.isEmpty)
                        Text(
                          'Aucun match.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: FutBoliaColors.inkMuted,
                              ),
                        )
                      else
                        ..._matches.map((m) {
                          final status = m['status']?.toString();
                          final score = status == 'finished'
                              ? '${m['homeScore']} – ${m['awayScore']}'
                              : 'vs';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            color: FutBoliaColors.surfaceRaised,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: FutBoliaColors.line),
                            ),
                            child: ListTile(
                              title: Text(
                                '${m['homeTeamName'] ?? '?'} $score ${m['awayTeamName'] ?? '?'}',
                              ),
                              subtitle: Text(FrLabels.matchStatus(status)),
                              trailing: widget.isOrganizer && status != 'cancelled'
                                  ? PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'score') {
                                          _scoreMatch(m);
                                        } else if (value == 'remove') {
                                          _cancelOrDelete(m);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'score',
                                          child: Text('Saisir le score'),
                                        ),
                                        PopupMenuItem(
                                          value: 'remove',
                                          child: Text(
                                            status == 'finished'
                                                ? 'Annuler le match'
                                                : 'Supprimer',
                                          ),
                                        ),
                                      ],
                                    )
                                  : FbBadge(
                                      label: FrLabels.matchStatus(status),
                                    ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
