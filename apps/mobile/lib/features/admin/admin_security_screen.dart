import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';

class AdminSecurityScreen extends StatefulWidget {
  const AdminSecurityScreen({super.key});

  @override
  State<AdminSecurityScreen> createState() => _AdminSecurityScreenState();
}

class _AdminSecurityScreenState extends State<AdminSecurityScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

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
      final data = await context.read<AuthSession>().api.adminSecurity();
      if (!mounted) return;
      setState(() => _data = data);
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
    final logs = (_data['logs'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final dbOk = _data['databaseConnected'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Sécurité')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: FutBoliaColors.danger)),
            if (_loading) const LinearProgressIndicator(),
            Card(
              child: ListTile(
                title: const Text('Base de données'),
                subtitle: Text(dbOk ? 'Connectée' : 'Hors ligne'),
                trailing: Icon(
                  dbOk ? Icons.check_circle : Icons.error_outline,
                  color: dbOk ? FutBoliaColors.pitch : FutBoliaColors.danger,
                ),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Sessions actives'),
                trailing: Text('${_data['activeSessions'] ?? '—'}'),
              ),
            ),
            const SizedBox(height: 16),
            Text('Journal d’audit', style: Theme.of(context).textTheme.titleMedium),
            if (!_loading && logs.isEmpty) const Text('Aucune action récente.'),
            ...logs.map(
              (log) => ListTile(
                title: Text(log['action']?.toString() ?? ''),
                subtitle: Text(
                  '${staffPseudoOf(log['admin'])} · ${log['createdAt'] ?? ''}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
