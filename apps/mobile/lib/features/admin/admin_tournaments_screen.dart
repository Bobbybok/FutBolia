import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';

class AdminTournamentsScreen extends StatefulWidget {
  const AdminTournamentsScreen({super.key});

  @override
  State<AdminTournamentsScreen> createState() => _AdminTournamentsScreenState();
}

class _AdminTournamentsScreenState extends State<AdminTournamentsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.adminListTournaments();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _open(Map<String, dynamic> tournament) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdminTournamentDetail(tournament: tournament),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournois')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: FutBoliaColors.danger)),
            if (_loading) const LinearProgressIndicator(),
            if (!_loading && _items.isEmpty) const Text('Aucun tournoi.'),
            ..._items.map(
              (t) => Card(
                child: ListTile(
                  title: Text(t['name']?.toString() ?? ''),
                  subtitle: Text(
                    '${t['status']} · ${t['memberCount']} joueurs · orga ${staffPseudoOf(t['owner'])}',
                  ),
                  onTap: () => _open(t),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTournamentDetail extends StatefulWidget {
  const _AdminTournamentDetail({required this.tournament});

  final Map<String, dynamic> tournament;

  @override
  State<_AdminTournamentDetail> createState() => _AdminTournamentDetailState();
}

class _AdminTournamentDetailState extends State<_AdminTournamentDetail> {
  bool _busy = false;
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _matches = [];

  ApiClient get _api => context.read<AuthSession>().api;
  String get _id => widget.tournament['id'] as String;

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    try {
      final teams = await _api.adminListTournamentTeams(_id);
      final matches = await _api.adminListTournamentMatches(_id);
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _matches = matches;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OK')),
      );
      await _loadExtras();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transfer() async {
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Nouveau propriétaire'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Pseudo ou e-mail'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Chercher'),
            ),
          ],
        );
      },
    );
    if (query == null || !mounted) return;
    try {
      final users = await _api.adminSearchUsers(query);
      if (!mounted) return;
      if (users.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun joueur trouvé')),
        );
        return;
      }
      final chosen = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => ListView(
          children: users
              .map(
                (u) => ListTile(
                  title: Text(staffPseudoOf(u)),
                  subtitle: Text(u['email']?.toString() ?? ''),
                  onTap: () => Navigator.pop(ctx, u),
                ),
              )
              .toList(),
        ),
      );
      if (chosen == null || !mounted) return;
      await _run(
        () => _api.adminTransferOwner(
          tournamentId: _id,
          userId: chosen['id'] as String,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce tournoi ?'),
        content: Text(widget.tournament['name']?.toString() ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await _api.adminDeleteTournament(_id);
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    return Scaffold(
      appBar: AppBar(title: Text(t['name']?.toString() ?? 'Tournoi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Statut : ${t['status']}'),
          Text('Lieu : ${t['location']}'),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _run(
              () => _api.adminPatchTournament(_id, {'status': 'cancelled'}),
            ),
            child: const Text('Annuler le tournoi'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _transfer, child: const Text('Transférer l’orga')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _delete,
            style: OutlinedButton.styleFrom(foregroundColor: FutBoliaColors.danger),
            child: const Text('Supprimer'),
          ),
          const SizedBox(height: 24),
          Text('Équipes', style: Theme.of(context).textTheme.titleMedium),
          if (_teams.isEmpty) const Text('Aucune équipe.'),
          ..._teams.map(
            (team) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(team['name']?.toString() ?? ''),
              subtitle: Text(team['status']?.toString() ?? ''),
              trailing: TextButton(
                onPressed: () => _run(
                  () => _api.adminForceTeamStatus(
                    teamId: team['id'] as String,
                    status: 'validated',
                  ),
                ),
                child: const Text('Valider'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Matchs', style: Theme.of(context).textTheme.titleMedium),
          if (_matches.isEmpty) const Text('Aucun match.'),
          ..._matches.map(
            (match) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(match['status']?.toString() ?? ''),
              subtitle: Text(match['scheduledAt']?.toString() ?? ''),
              trailing: match['status'] == 'cancelled'
                  ? null
                  : TextButton(
                      onPressed: () => _run(
                        () => _api.adminCancelMatch(match['id'] as String),
                      ),
                      child: const Text('Annuler'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
