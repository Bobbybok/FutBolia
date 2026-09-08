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
      setState(() => _users = users);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Chargement impossible';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
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

  String get _id => _user['id'] as String;

  Map<String, dynamic> get _profile {
    final raw = _user['profile'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      final fresh = await _api.adminGetUser(_id);
      if (!mounted) return;
      setState(() => _user = fresh);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _prompt({
    required String title,
    required String label,
    String initial = '',
    TextInputType? keyboardType,
    bool obscure = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _editEmail() async {
    final value = await _prompt(
      title: 'Modifier l’e-mail',
      label: 'Nouvel e-mail',
      initial: _user['email']?.toString() ?? '',
      keyboardType: TextInputType.emailAddress,
    );
    final email = value?.trim();
    if (email == null || email.isEmpty) return;
    await _run(() => _api.adminPatchUser(_id, {'email': email}));
  }

  Future<void> _editPseudo() async {
    final value = await _prompt(
      title: 'Modifier le pseudo',
      label: 'Pseudo',
      initial: _profile['pseudo']?.toString() ??
          _user['pseudo']?.toString() ??
          '',
    );
    final pseudo = value?.trim();
    if (pseudo == null || pseudo.isEmpty) return;
    await _run(() => _api.adminPatchUser(_id, {'pseudo': pseudo}));
  }

  Future<void> _editProfile() async {
    final first = await _prompt(
      title: 'Prénom',
      label: 'Prénom',
      initial: _profile['firstName']?.toString() ?? '',
    );
    if (first == null || !mounted) return;
    final city = await _prompt(
      title: 'Ville',
      label: 'Ville',
      initial: _profile['city']?.toString() ?? '',
    );
    if (city == null) return;
    await _run(
      () => _api.adminPatchUser(_id, {
        'firstName': first.trim(),
        'city': city.trim(),
      }),
    );
  }

  Future<void> _editPassword() async {
    final value = await _prompt(
      title: 'Nouveau mot de passe',
      label: 'Au moins 8 caractères',
      obscure: true,
    );
    final password = value?.trim();
    if (password == null || password.isEmpty) return;
    if (password.length < 8) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit faire 8 caractères.')),
      );
      return;
    }
    await _run(() => _api.adminPatchUser(_id, {'password': password}));
  }

  Future<void> _deleteUser() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text(
          '${staffPseudoOf(_user)}\n${_user['email'] ?? ''}\n\n'
          'Le compte est désactivé. E-mail et pseudo sont libérés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _api.adminDeleteUser(_id);
      if (!mounted) return;
      Navigator.of(context).pop();
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
    final firstName = _profile['firstName']?.toString() ?? '';
    final city = _profile['city']?.toString() ?? '';

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
          if (firstName.isNotEmpty || city.isNotEmpty)
            Text(
              [if (firstName.isNotEmpty) firstName, if (city.isNotEmpty) city]
                  .join(' · '),
            ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _busy ? null : _editEmail,
            child: const Text('Modifier l’e-mail'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _editPseudo,
            child: const Text('Modifier le pseudo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _editProfile,
            child: const Text('Modifier prénom / ville'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _editPassword,
            child: const Text('Définir un mot de passe'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy
                ? null
                : banned
                    ? () => _run(() => _api.adminUnbanUser(_id))
                    : () => _run(() => _api.adminBanUser(_id)),
            child: Text(banned ? 'Débannir' : 'Bannir'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(() => _api.adminForceVerify(_id)),
            child: const Text('Forcer la vérification e-mail'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(() => _api.adminForceReset(_id)),
            child: const Text('Envoyer un reset mot de passe'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(() => _api.adminRevokeSessions(_id)),
            child: const Text('Révoquer les sessions'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _deleteUser,
            style: OutlinedButton.styleFrom(
              foregroundColor: FutBoliaColors.danger,
            ),
            child: const Text('Supprimer le compte'),
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
