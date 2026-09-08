import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};

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
      final stats = await context.read<AuthSession>().api.adminStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Chargement impossible';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: FutBoliaColors.danger)),
            if (_loading) const LinearProgressIndicator(),
            _tile('Utilisateurs', _stats['users']),
            _tile('Admins', _stats['admins']),
            _tile('Modérateurs', _stats['moderators']),
            _tile('Tournois', _stats['tournaments']),
            _tile('Matchs', _stats['matches']),
            _tile('Signalements ouverts', _stats['openReports']),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, dynamic value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text('${value ?? '—'}'),
      ),
    );
  }
}
