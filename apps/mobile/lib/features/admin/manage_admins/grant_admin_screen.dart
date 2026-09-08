import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/domain/staff_label.dart';
import '../admin_permissions.dart';

class GrantAdminScreen extends StatefulWidget {
  const GrantAdminScreen({super.key});

  @override
  State<GrantAdminScreen> createState() => _GrantAdminScreenState();
}

class _GrantAdminScreenState extends State<GrantAdminScreen> {
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _admins = [];
  List<Map<String, dynamic>> _users = [];

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final admins = await _api.adminListAdmins();
      if (!mounted) return;
      setState(() {
        _admins = admins;
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

  Future<void> _editPermissions(Map<String, dynamic> user, {required bool grant}) async {
    final current = (user['permissions'] as List? ?? [])
        .map((e) => e.toString())
        .toSet();
    final selected = {...current};
    if (selected.isEmpty) {
      selected.addAll(AdminPermissions.all);
    }

    final confirmed = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grant ? 'Accorder l’accès admin' : 'Modifier les permissions',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  Text(user['email']?.toString() ?? ''),
                  const SizedBox(height: 12),
                  ...AdminPermissions.all.map((permission) {
                    return CheckboxListTile(
                      value: selected.contains(permission),
                      onChanged: (v) {
                        setModal(() {
                          if (v == true) {
                            selected.add(permission);
                          } else {
                            selected.remove(permission);
                          }
                        });
                      },
                      title: Text(AdminPermissions.label(permission)),
                      subtitle: Text(AdminPermissions.hint(permission)),
                    );
                  }),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, selected),
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == null || !mounted) return;
    try {
      if (grant) {
        await _api.adminGrant(
          userId: user['id'] as String,
          permissions: confirmed.toList(),
        );
      } else {
        await _api.adminUpdatePermissions(
          userId: user['id'] as String,
          permissions: confirmed.toList(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions mises à jour. La personne doit se reconnecter.')),
      );
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _revoke(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer l’accès admin ?'),
        content: Text(user['email']?.toString() ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.adminRevoke(user['id'] as String);
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admins')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Rechercher un joueur (pseudo ou e-mail)',
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
          if (_users.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Résultats', style: Theme.of(context).textTheme.titleMedium),
            ..._users.map((user) {
              final isAdmin = user['role'] == 'admin';
              return ListTile(
                title: Text(staffPseudoOf(user)),
                subtitle: Text(user['email']?.toString() ?? ''),
                trailing: TextButton(
                  onPressed: () => _editPermissions(user, grant: !isAdmin || (user['permissions'] as List? ?? []).isEmpty),
                  child: Text(isAdmin ? 'Modifier' : 'Admin'),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          Text('Admins actuels', style: Theme.of(context).textTheme.titleMedium),
          ..._admins.map((admin) {
            final perms = (admin['permissions'] as List? ?? []).map((e) => e.toString());
            return Card(
              child: ListTile(
                title: Text(staffPseudoOf(admin)),
                subtitle: Text(
                  '${admin['email']}\n${perms.map(AdminPermissions.label).join(', ')}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: () => _editPermissions(admin, grant: false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_off_outlined),
                      onPressed: () => _revoke(admin),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
