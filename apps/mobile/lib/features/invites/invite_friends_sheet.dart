import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/components/fb_button.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';

/// Bottom sheet: search any player by pseudo and invite them.
Future<void> showInviteFriendsSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InvitePlayersSheet(
      targetType: targetType,
      targetId: targetId,
      title: title,
    ),
  );
}

class _InvitePlayersSheet extends StatefulWidget {
  const _InvitePlayersSheet({
    required this.targetType,
    required this.targetId,
    required this.title,
  });

  final String targetType;
  final String targetId;
  final String title;

  @override
  State<_InvitePlayersSheet> createState() => _InvitePlayersSheetState();
}

class _InvitePlayersSheetState extends State<_InvitePlayersSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  bool _searching = false;
  bool _sending = false;
  String? _error;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _results = [];
  final Set<String> _selected = {};

  bool get _isSearching => _searchCtrl.text.trim().length >= 2;

  List<Map<String, dynamic>> get _people =>
      _isSearching ? _results : _friends;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final friends = await context.read<AuthSession>().api.listFriends();
      if (!mounted) return;
      setState(() => _friends = friends);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Chargement impossible';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 320), () {
      _search(q);
    });
  }

  Future<void> _search(String query) async {
    try {
      final hits = await context.read<AuthSession>().api.searchPlayers(query);
      if (!mounted || _searchCtrl.text.trim() != query) return;
      setState(() {
        _results = hits;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send() async {
    final query = _searchCtrl.text.trim();
    final ids = {..._selected};
    final pseudos = <String>[];

    if (ids.isEmpty && query.length >= 2) {
      final exact = _people
          .where(
            (p) =>
                p['pseudo']?.toString().toLowerCase() == query.toLowerCase(),
          )
          .toList();
      if (exact.length == 1) {
        ids.add(exact.first['id'] as String);
      } else if (_people.length == 1) {
        ids.add(_people.first['id'] as String);
      } else {
        pseudos.add(query);
      }
    }

    if (ids.isEmpty && pseudos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tape un pseudo ou coche un joueur'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await context.read<AuthSession>().api.createEventInvites(
            targetType: widget.targetType,
            targetId: widget.targetId,
            friendIds: ids.toList(),
            userIds: ids.toList(),
            pseudos: pseudos,
          );
      if (!mounted) return;
      final count = (result['invited'] as num?)?.toInt() ?? ids.length;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count <= 0
                ? 'Aucune nouvelle invitation (déjà dans l’événement ?)'
                : '$count invitation(s) envoyée(s)',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final canSend = _selected.isNotEmpty || _searchCtrl.text.trim().length >= 2;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inviter un joueur',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: FutBoliaColors.inkMuted,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) {
                        _debounce?.cancel();
                        if (_searchCtrl.text.trim().length >= 2) {
                          _search(_searchCtrl.text.trim());
                        }
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Rechercher un pseudo',
                        hintText: 'Ex. Yosh',
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading || _searching) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: FutBoliaColors.danger),
                  ),
                ),
              Expanded(
                child: _people.isEmpty && !_loading && !_searching
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _isSearching
                                ? 'Aucun joueur pour « ${_searchCtrl.text.trim()} »'
                                : 'Tape un pseudo pour inviter n’importe quel joueur.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _people.length,
                        itemBuilder: (context, i) {
                          final player = _people[i];
                          final id = player['id'] as String;
                          final selected = _selected.contains(id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(id);
                                } else {
                                  _selected.remove(id);
                                }
                              });
                            },
                            title: Text(staffPseudoOf(player)),
                            subtitle: player['city'] == null
                                ? null
                                : Text(player['city'].toString()),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FbButton(
                  label: _selected.isEmpty
                      ? (_searchCtrl.text.trim().length >= 2
                          ? 'Inviter « ${_searchCtrl.text.trim()} »'
                          : 'Recherche un pseudo')
                      : 'Inviter (${_selected.length})',
                  loading: _sending,
                  onPressed: !canSend || _sending ? null : _send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
