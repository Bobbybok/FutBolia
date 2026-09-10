import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/fr_labels.dart';
import '../../core/network/api_client.dart';
import '../../core/realtime/live_bindings.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';

class AdminPickupsScreen extends StatefulWidget {
  const AdminPickupsScreen({super.key});

  @override
  State<AdminPickupsScreen> createState() => _AdminPickupsScreenState();
}

class _AdminPickupsScreenState extends State<AdminPickupsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final _live = LiveBindings();

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _reload();
    _live.listenLobby('pickup', () {
      if (mounted) _reload(silent: true);
    });
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await _api.adminListPickupMatches();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Chargement impossible';
      });
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _api.adminDeletePickup(id);
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _cancel(String id) async {
    try {
      await _api.adminPatchPickup(id, {'status': 'cancelled'});
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matchs libres')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: FutBoliaColors.danger)),
            if (_loading) const LinearProgressIndicator(),
            if (!_loading && _items.isEmpty) const Text('Aucun match libre.'),
            ..._items.map(
              (m) => Card(
                child: ListTile(
                  title: Text(m['location']?.toString() ?? ''),
                  subtitle: Text(
                    '${FrLabels.matchStatus(m['status']?.toString())} · hôte ${staffPseudoOf(m['host'])}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      final id = m['id']?.toString() ?? '';
                      if (value == 'cancel') _cancel(id);
                      if (value == 'delete') _delete(id);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'cancel', child: Text('Annuler')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
