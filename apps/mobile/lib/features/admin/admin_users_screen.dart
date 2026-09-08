import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _searchUsers();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _api.adminSearchUsers(_search.text);
      if (!mounted) return;
      setState(() {
        _users = users;
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

  Future<void> _openUser(String id) async {
    try {
      final detail = await _api.adminGetUser(id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _AdminUserDetail(user: detail)),
      );
      await _searchUsers();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Pseudo ou e-mail',
              suffixIcon: IconButton(
                onPressed: _searchUsers,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _searchUsers(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: FutBoliaColors.danger)),
          ],
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          ..._users.map(
            (user) => ListTile(
              title: Text(staffPseudoOf(user)),
              subtitle: Text(
                '${user['email']} · ${user['status'] ?? ''}',
              ),
              onTap: () => _openUser(user['id'] as String),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminUserDetail extends StatefulWidget {
  const _AdminUserDetail({required this.user});

  final Map<String, dynamic> user;

  @override
  State<_AdminUserDetail> createState() => _AdminUserDetailState();
}

class _AdminUserDetailState extends State<_AdminUserDetail> {
  late Map<String, dynamic> _user;
  bool _busy = false;

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      final fresh = await _api.adminGetUser(_user['id'] as String);
      if (!mounted) return;
      setState(() => _user = fresh);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _user['status']?.toString() ?? '';
    final banned = status == 'banned' || status == 'suspended';
    final history = (_user['tournaments'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(staffPseudoOf(_user))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_user['email']?.toString() ?? ''),
          Text('Statut : $status · sessions : ${_user['activeSessions'] ?? 0}'),
          Text(
            _user['emailVerified'] == true ? 'E-mail vérifié' : 'E-mail non vérifié',
          ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: banned
                ? () => _run(() => _api.adminUnbanUser(_user['id'] as String))
                : () => _run(() => _api.adminBanUser(_user['id'] as String)),
            child: Text(banned ? 'Débannir' : 'Bannir'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _run(() => _api.adminForceVerify(_user['id'] as String)),
            child: const Text('Forcer la vérification e-mail'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _run(() => _api.adminForceReset(_user['id'] as String)),
            child: const Text('Envoyer un reset mot de passe'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _run(() => _api.adminRevokeSessions(_user['id'] as String)),
            child: const Text('Révoquer les sessions'),
          ),
          const SizedBox(height: 24),
          Text('Historique tournois', style: Theme.of(context).textTheme.titleMedium),
          if (history.isEmpty) const Text('Aucune participation.'),
          ...history.map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t['name']?.toString() ?? ''),
              subtitle: Text(t['role']?.toString() ?? ''),
            ),
          ),
        ],
      ),
    );
  }
}
