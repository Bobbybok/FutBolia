import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _messages = [];

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
      final reports = await _api.adminListReports();
      final messages = await _api.adminListDeletedMessages();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _messages = messages;
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

  Future<void> _resolve(String id, String status) async {
    try {
      await _api.adminResolveReport(id: id, status: status);
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modération')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: FutBoliaColors.danger)),
            if (_loading) const LinearProgressIndicator(),
            Text('Signalements', style: Theme.of(context).textTheme.titleMedium),
            if (!_loading && _reports.isEmpty) const Text('Aucun signalement.'),
            ..._reports.map(
              (r) => Card(
                child: ListTile(
                  title: Text('${r['type']} · ${staffPseudoOf(r['reporter'])}'),
                  subtitle: Text(r['reason']?.toString() ?? ''),
                  isThreeLine: true,
                  trailing: r['status'] == 'open'
                      ? Wrap(
                          children: [
                            TextButton(
                              onPressed: () => _resolve(r['id'] as String, 'reviewed'),
                              child: const Text('Traité'),
                            ),
                            TextButton(
                              onPressed: () => _resolve(r['id'] as String, 'dismissed'),
                              child: const Text('Rejeter'),
                            ),
                          ],
                        )
                      : Text(r['status']?.toString() ?? ''),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Messages supprimés', style: Theme.of(context).textTheme.titleMedium),
            if (!_loading && _messages.isEmpty)
              const Text('Aucun message supprimé récemment.'),
            ..._messages.map(
              (m) => ListTile(
                title: Text(staffPseudoOf(m['author'])),
                subtitle: Text(m['body']?.toString() ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
