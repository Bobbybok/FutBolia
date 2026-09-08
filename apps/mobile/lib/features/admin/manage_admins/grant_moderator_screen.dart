import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/domain/staff_label.dart';
import '../admin_permissions.dart';

class GrantModeratorScreen extends StatefulWidget {
  const GrantModeratorScreen({super.key});

  @override
  State<GrantModeratorScreen> createState() => _GrantModeratorScreenState();
}

class _GrantModeratorScreenState extends State<GrantModeratorScreen> {
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _moderators = [];
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
      final moderators = await _api.adminListModerators();
      if (!mounted) return;
      setState(() => _moderators = moderators);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Chargement impossible';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
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

  Future<void> _editPermissions(
    Map<String, dynamic> user, {
    required bool grant,
  }) async {
    final actor = context.read<AuthSession>().user;
    final actorIsAdmin = actor?.isAdmin ?? false;

    if (!actorIsAdmin) {
      if (!grant) return;
      await _grantDefault(user);
      return;
    }

    final current = (user['permissions'] as List? ?? [])
        .map((e) => e.toString())
        .toSet();
    final selected = {...current};
    selected.add(AdminPermissions.moderateContent);

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
                    grant
                        ? 'Accorder le rôle modérateur'
                        : 'Modifier les droits modo',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  Text(user['email']?.toString() ?? ''),
                  const SizedBox(height: 8),
                  Text(
                    grant
                        ? 'Nouveau modo : modération seule par défaut. Coche le reste si besoin.'
                        : 'Coche ce qu’il a le droit de faire. La modération chat reste toujours active.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: FutBoliaColors.inkMuted,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...AdminPermissions.forModerators.map((permission) {
                    final locked = permission == AdminPermissions.moderateContent;
                    return CheckboxListTile(
                      value: selected.contains(permission) || locked,
                      onChanged: locked
                          ? null
                          : (v) {
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
    final perms = {
      ...confirmed,
      AdminPermissions.moderateContent,
    }.toList();
    try {
      if (grant) {
        await _api.adminGrantModerator(
          userId: user['id'] as String,
          permissions: perms,
        );
      } else {
        await _api.adminUpdateModeratorPermissions(
          userId: user['id'] as String,
          permissions: perms,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Droits enregistrés. La personne doit se reconnecter.'),
        ),
      );
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _grantDefault(Map<String, dynamic> user) async {
    try {
      await _api.adminGrantModerator(
        userId: user['id'] as String,
        permissions: [AdminPermissions.moderateContent],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modérateur ajouté (modération seule). Il doit se reconnecter.'),
        ),
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
        title: const Text('Retirer le rôle modérateur ?'),
        content: Text(staffPseudoOf(user)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.adminRevokeModerator(user['id'] as String);
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actorIsAdmin = context.watch<AuthSession>().user?.isAdmin ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Modérateurs')),
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
              final role = user['role']?.toString();
              final already = role == 'moderator';
              return ListTile(
                title: Text(staffPseudoOf(user)),
                subtitle: Text(user['email']?.toString() ?? ''),
                trailing: already
                    ? (actorIsAdmin
                        ? TextButton(
                            onPressed: () => _editPermissions(user, grant: false),
                            child: const Text('Modifier'),
                          )
                        : const Text('Modo'))
                    : TextButton(
                        onPressed: role == 'admin'
                            ? null
                            : () => _editPermissions(user, grant: true),
                        child: const Text('Modo'),
                      ),
              );
            }),
          ],
          const SizedBox(height: 24),
          Text('Modérateurs actuels', style: Theme.of(context).textTheme.titleMedium),
          if (_moderators.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Aucun modérateur pour l’instant.'),
            ),
          ..._moderators.map((mod) {
            final perms = (mod['permissions'] as List? ?? [])
                .map((e) => e.toString());
            return Card(
              child: ListTile(
                title: Text(staffPseudoOf(mod)),
                subtitle: Text(
                  '${mod['email']}\n${perms.map(AdminPermissions.label).join(', ')}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  children: [
                    if (actorIsAdmin)
                      IconButton(
                        icon: const Icon(Icons.tune),
                        onPressed: () => _editPermissions(mod, grant: false),
                      ),
                    IconButton(
                      icon: const Icon(Icons.person_off_outlined),
                      onPressed: () => _revoke(mod),
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

