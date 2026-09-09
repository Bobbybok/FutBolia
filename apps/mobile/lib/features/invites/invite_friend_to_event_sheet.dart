import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../auth/domain/staff_label.dart';

/// From a friend tile: pick one of my private events and invite that friend.
Future<void> showInviteFriendToEventSheet(
  BuildContext context, {
  required Map<String, dynamic> friend,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InviteFriendToEventSheet(friend: friend),
  );
}

class _InviteFriendToEventSheet extends StatefulWidget {
  const _InviteFriendToEventSheet({required this.friend});

  final Map<String, dynamic> friend;

  @override
  State<_InviteFriendToEventSheet> createState() =>
      _InviteFriendToEventSheetState();
}

class _InviteFriendToEventSheetState extends State<_InviteFriendToEventSheet> {
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<_InviteTarget> _targets = [];

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
      final api = context.read<AuthSession>().api;
      final me = context.read<AuthSession>().user!.id;
      final tournaments = await api.listTournaments(mine: true);
      final matches = await api.listPickupMatches(mine: true);
      final targets = <_InviteTarget>[];

      for (final t in tournaments) {
        if (t['visibility']?.toString() != 'private') continue;
        if (t['myRole']?.toString() != 'organizer' &&
            t['createdById']?.toString() != me) {
          continue;
        }
        targets.add(
          _InviteTarget(
            type: 'tournament',
            id: t['id'] as String,
            label: t['name']?.toString() ?? 'Tournoi',
            kind: 'Tournoi',
          ),
        );
      }

      for (final m in matches) {
        if (m['visibility']?.toString() != 'private') continue;
        if (m['isHost'] != true && m['createdById']?.toString() != me) {
          continue;
        }
        if (m['status']?.toString() != 'open') continue;
        targets.add(
          _InviteTarget(
            type: 'pickup_match',
            id: m['id'] as String,
            label:
                '${m['location']} · ${m['playersPerTeam']}v${m['playersPerTeam']}',
            kind: 'Match',
          ),
        );
      }

      if (!mounted) return;
      setState(() => _targets = targets);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Chargement impossible';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite(_InviteTarget target) async {
    setState(() => _sending = true);
    try {
      await context.read<AuthSession>().api.createEventInvites(
            targetType: target.type,
            targetId: target.id,
            friendIds: [widget.friend['id'] as String],
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${staffPseudoOf(widget.friend)} invité · ${target.label}',
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
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inviter ${staffPseudoOf(widget.friend)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choisis un tournoi ou match privé que tu organises.',
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
              child: _targets.isEmpty && !_loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucun événement privé à partager. Crée un tournoi ou match privé d’abord.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _targets.length,
                      itemBuilder: (context, i) {
                        final t = _targets[i];
                        return ListTile(
                          leading: Icon(
                            t.type == 'tournament'
                                ? Icons.emoji_events_outlined
                                : Icons.sports_soccer_outlined,
                          ),
                          title: Text(t.label),
                          subtitle: Text(t.kind),
                          trailing: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_outlined),
                          onTap: _sending ? null : () => _invite(t),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteTarget {
  const _InviteTarget({
    required this.type,
    required this.id,
    required this.label,
    required this.kind,
  });

  final String type;
  final String id;
  final String label;
  final String kind;
}
