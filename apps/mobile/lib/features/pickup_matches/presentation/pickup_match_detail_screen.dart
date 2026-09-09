import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/domain/staff_label.dart';

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
  final _code = TextEditingController();
  final _homeScore = TextEditingController();
  final _awayScore = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
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
      await context.read<AuthSession>().api.joinPickupMatch(
            widget.matchId,
            code: _code.text.trim().isEmpty ? null : _code.text.trim(),
          );
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
    final isPrivate = m['visibility'] == 'private';
    final status = m['status']?.toString();
    final joinCode = m['joinCode']?.toString();
    final members = (m['members'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final home = members.where((e) => e['side'] == 'home').toList();
    final away = members.where((e) => e['side'] == 'away').toList();
    final canJoin = !isMember &&
        (status == 'open') &&
        status != 'cancelled' &&
        status != 'finished';
    final canLeave = isMember &&
        !isHost &&
        status != 'finished' &&
        status != 'cancelled';
    final canScore = isHost &&
        status != 'finished' &&
        status != 'cancelled';
    final canCancel = isHost &&
        status != 'finished' &&
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
                background: const Color(0xFFE3F2FD),
              ),
              FbBadge(
                label: '${m['membersCount'] ?? 0} / ${m['capacity'] ?? '?'}',
                background: const Color(0xFFE8F5E9),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Lieu : ${m['location']}'),
          Text('Date : ${_formatDate(m['scheduledAt'])}'),
          Text('Format : ${m['playersPerTeam']} vs ${m['playersPerTeam']}'),
          if (m['mySide'] != null)
            Text('Ton équipe : ${FrLabels.pickupSide(m['mySide']?.toString())}'),
          if (status == 'finished') ...[
            const SizedBox(height: 12),
            Text(
              'Score : ${m['homeScore']} — ${m['awayScore']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          if (joinCode != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Code d’accès : $joinCode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: joinCode));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copié')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (canJoin) ...[
            if (isPrivate)
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Code du match'),
              ),
            if (isPrivate) const SizedBox(height: 12),
            FbButton(
              label: 'Rejoindre le match',
              loading: _joining,
              onPressed: _join,
            ),
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
              'Saisie du score (hôte)',
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
          const SizedBox(height: 28),
          Text('Équipe A', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._memberTiles(home),
          if (home.isEmpty)
            Text(
              'Aucun joueur pour l’instant',
              style: TextStyle(color: FutBoliaColors.inkMuted),
            ),
          const SizedBox(height: 20),
          Text('Équipe B', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._memberTiles(away),
          if (away.isEmpty)
            Text(
              'Aucun joueur pour l’instant',
              style: TextStyle(color: FutBoliaColors.inkMuted),
            ),
        ],
      ),
    );
  }

  List<Widget> _memberTiles(List<Map<String, dynamic>> members) {
    return members.map((m) {
      final user = m['user'] as Map<String, dynamic>? ?? {};
      final pseudo = staffPseudoOf(user);
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(pseudo),
      );
    }).toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Date inconnue';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return dt.toLocal().toString().substring(0, 16);
  }
}
