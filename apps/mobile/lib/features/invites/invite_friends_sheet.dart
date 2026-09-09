import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/components/fb_button.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';

/// Bottom sheet: pick friends to invite to a private tournament or pickup match.
Future<void> showInviteFriendsSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InviteFriendsSheet(
      targetType: targetType,
      targetId: targetId,
      title: title,
    ),
  );
}

class _InviteFriendsSheet extends StatefulWidget {
  const _InviteFriendsSheet({
    required this.targetType,
    required this.targetId,
    required this.title,
  });

  final String targetType;
  final String targetId;
  final String title;

  @override
  State<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<_InviteFriendsSheet> {
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _selected = {};

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

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);
    try {
      final result = await context.read<AuthSession>().api.createEventInvites(
            targetType: widget.targetType,
            targetId: widget.targetId,
            friendIds: _selected.toList(),
          );
      if (!mounted) return;
      final count = (result['invited'] as num?)?.toInt() ?? _selected.length;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count <= 0
                ? 'Aucune nouvelle invitation (déjà invités ?)'
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
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inviter des amis',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: FutBoliaColors.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: FutBoliaColors.danger),
                  ),
                ),
              Expanded(
                child: _friends.isEmpty && !_loading
                    ? const Center(child: Text('Aucun ami à inviter'))
                    : ListView.builder(
                        itemCount: _friends.length,
                        itemBuilder: (context, i) {
                          final friend = _friends[i];
                          final id = friend['id'] as String;
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
                            title: Text(staffPseudoOf(friend)),
                            subtitle: friend['city'] == null
                                ? null
                                : Text(friend['city'].toString()),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FbButton(
                  label: _selected.isEmpty
                      ? 'Sélectionne des amis'
                      : 'Inviter (${_selected.length})',
                  loading: _sending,
                  onPressed: _selected.isEmpty || _sending ? null : _send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
