import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_atmosphere.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/domain/staff_label.dart';
import '../../admin/admin_permissions.dart';
import '../../admin/admin_users_screen.dart';
import '../../private_chat/conversation_screen.dart';
import '../player_profile_labels.dart';
import '../widgets/player_avatar.dart';
import '../career_actions.dart';

String? userIdOf(dynamic value) {
  if (value is! Map) return null;
  for (final key in ['userId', 'authorId']) {
    final v = value[key]?.toString();
    if (v != null && v.isNotEmpty) return v;
  }
  final nested = value['user'];
  if (nested is Map) {
    final v = nested['id']?.toString();
    if (v != null && v.isNotEmpty) return v;
  }
  final friend = value['friend'];
  if (friend is Map) {
    final v = friend['id']?.toString();
    if (v != null && v.isNotEmpty) return v;
  }
  if (value['body'] == null && value['content'] == null) {
    final v = value['id']?.toString();
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

void openPublicProfile(BuildContext context, String? userId) {
  if (userId == null || userId.isEmpty) return;
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => PublicProfileScreen(userId: userId),
    ),
  );
}

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _loading = true;
  bool _friendBusy = false;
  String? _error;
  Map<String, dynamic>? _data;

  ApiClient get _api => context.read<AuthSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _api.getPublicUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  Future<void> _toggleHidden(Map<String, dynamic> item, bool hidden) async {
    try {
      final career = await _api.hideCareerItem(
        itemType: item['kind']?.toString() ?? 'tournament',
        itemId: item['id']?.toString() ?? '',
        hidden: hidden,
      );
      if (!mounted || _data == null) return;
      setState(() {
        _data = {
          ..._data!,
          'stats': career['stats'],
          'tournaments': career['tournaments'],
          'matches': career['matches'],
        };
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteCareer(Map<String, dynamic> item) async {
    final choice = await confirmCareerDelete(
      context,
      item,
      isOwnProfile: _data?['isOwner'] == true,
    );
    if (choice == null || !mounted) return;
    try {
      final career = await applyCareerDelete(
        api: _api,
        item: item,
        choice: choice,
        profileUserId: widget.userId,
      );
      if (!mounted || _data == null) return;
      if (career != null) {
        setState(() {
          _data = {
            ..._data!,
            'stats': career['stats'],
            'tournaments': career['tournaments'],
            'matches': career['matches'],
          };
        });
      } else {
        await _load(quiet: true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _friendAction(Future<void> Function() action) async {
    if (_friendBusy) return;
    setState(() => _friendBusy = true);
    try {
      await action();
      await _load(quiet: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _friendBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(_data?['profile'] as Map? ?? {});
    final stats = Map<String, dynamic>.from(_data?['stats'] as Map? ?? {});
    final tournaments = _asMaps(_data?['tournaments']);
    final matches = _asMaps(_data?['matches']);
    final isOwner = _data?['isOwner'] == true;
    final positions = normalizePositions(profile['positions'], profile['position']?.toString());
    final availability = asStringList(profile['availability']);
    final title = staffDisplayPseudo(
      profile['pseudo']?.toString(),
      _data?['role']?.toString(),
    );

    return Scaffold(
      backgroundColor: FutBoliaColors.surfaceDark,
      body: FbAtmosphere(
        safeArea: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      isOwner ? 'Mon profil public' : 'Profil',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          children: [
                            Center(
                              child: PlayerAvatar(
                                userId: widget.userId,
                                avatarUrl: profile['avatarUrl']?.toString(),
                                radius: 46,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            if ((profile['city']?.toString() ?? '').isNotEmpty)
                              Text(
                                profile['city'].toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            const SizedBox(height: 16),
                            _MiniBilan(stats: stats),
                            if (!isOwner) ...[
                              const SizedBox(height: 16),
                              _FriendActionButton(
                                friendship: _data?['friendship']?.toString(),
                                loading: _friendBusy,
                                onAdd: () => _friendAction(
                                  () async {
                                    await _api.sendFriendRequest(
                                      userId: widget.userId,
                                    );
                                  },
                                ),
                                onAccept: () {
                                  final requestId =
                                      _data?['friendshipRequestId']?.toString();
                                  if (requestId == null || requestId.isEmpty) {
                                    return;
                                  }
                                  _friendAction(
                                    () async {
                                      await _api.acceptFriendRequest(requestId);
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              FbButton(
                                label: 'Message privé',
                                variant: FbButtonVariant.secondary,
                                onPressed: () async {
                                  try {
                                    final conv = await _api.openConversation(
                                      widget.userId,
                                    );
                                    if (!context.mounted) return;
                                    openDirectChat(
                                      context,
                                      conversationId: conv['id'] as String,
                                      friendName: title,
                                      friendId: widget.userId,
                                      canSend: conv['canSend'] != false,
                                    );
                                  } on ApiException catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.message)),
                                    );
                                  }
                                },
                              ),
                            ],
                            if (context.watch<AuthSession>().user?.hasPermission(
                                  AdminPermissions.manageUsers,
                                ) ??
                                false) ...[
                              const SizedBox(height: 16),
                              FbButton(
                                label: 'Modifier ce profil (admin)',
                                variant: FbButtonVariant.secondary,
                                onPressed: () async {
                                  try {
                                    final detail = await _api
                                        .adminGetUser(widget.userId);
                                    if (!context.mounted) return;
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => AdminUserDetailScreen(
                                          user: detail,
                                        ),
                                      ),
                                    );
                                    await _load();
                                  } on ApiException catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.message)),
                                    );
                                  }
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            _InfoCard(
                              children: [
                                if (positions.isNotEmpty)
                                  _kv(
                                    'Postes',
                                    positions
                                        .asMap()
                                        .entries
                                        .map(
                                          (e) =>
                                              '${e.key + 1}. ${PlayerProfileLabels.positionLong(e.value)}',
                                        )
                                        .join('\n'),
                                  ),
                                if (profile['strongFoot'] != null)
                                  _kv(
                                    'Pied fort',
                                    PlayerProfileLabels.footLabel(
                                      profile['strongFoot']?.toString(),
                                    ),
                                  ),
                                if (profile['heightCm'] != null ||
                                    profile['weightKg'] != null)
                                  _kv(
                                    'Mensurations',
                                    [
                                      if (profile['heightCm'] != null)
                                        '${profile['heightCm']} cm',
                                      if (profile['weightKg'] != null)
                                        '${profile['weightKg']} kg',
                                    ].join(' · '),
                                  ),
                                if (profile['experienceLevel'] != null)
                                  _kv(
                                    'Expérience',
                                    [
                                      PlayerProfileLabels.experienceLabel(
                                        profile['experienceLevel']?.toString(),
                                      ),
                                      if (profile['playingSinceYear'] != null)
                                        'depuis ${profile['playingSinceYear']}',
                                    ].join(' · '),
                                  ),
                                if (availability.isNotEmpty)
                                  _kv(
                                    'Dispos',
                                    availability
                                        .map(PlayerProfileLabels.availabilityLabel)
                                        .join(' · '),
                                  ),
                                if ((profile['bio']?.toString() ?? '').isNotEmpty)
                                  _kv('Bio', profile['bio'].toString()),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Tournois (${tournaments.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (tournaments.isEmpty)
                              const Text(
                                'Aucun tournoi affiché.',
                                style: TextStyle(color: Colors.white70),
                              )
                            else
                              ...tournaments.map(
                                (item) => _CareerTile(
                                  item: item,
                                  isOwner: isOwner,
                                  onHidden: isOwner
                                      ? (hidden) => _toggleHidden(item, hidden)
                                      : null,
                                  onDelete: careerCanRemoveFromProfile(item) ||
                                          careerCanDeleteEvent(item)
                                      ? () => _deleteCareer(item)
                                      : null,
                                ),
                              ),
                            const SizedBox(height: 20),
                            Text(
                              'Matchs (${matches.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (matches.isEmpty)
                              const Text(
                                'Aucun match affiché.',
                                style: TextStyle(color: Colors.white70),
                              )
                            else
                              ...matches.map(
                                (item) => _CareerTile(
                                  item: item,
                                  isOwner: isOwner,
                                  onHidden: isOwner
                                      ? (hidden) => _toggleHidden(item, hidden)
                                      : null,
                                  onDelete: careerCanRemoveFromProfile(item) ||
                                          careerCanDeleteEvent(item)
                                      ? () => _deleteCareer(item)
                                      : null,
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Map<String, dynamic>> _asMaps(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class _MiniBilan extends StatelessWidget {
  const _MiniBilan({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat('Tournois', stats['tournaments']),
        _stat('Matchs', stats['matches']),
        _stat('Orga', stats['asOrganizer']),
        _stat('Cap.', stats['asCaptain']),
      ],
    );
  }

  Widget _stat(String label, dynamic value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: FutBoliaColors.cardDark.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FutBoliaColors.lime.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '${value ?? 0}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const Text(
        'Ce joueur n’a pas encore rempli son profil sport.',
        style: TextStyle(color: Colors.white70),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FutBoliaColors.cardDark.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FutBoliaColors.lime.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

Widget _kv(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: FutBoliaColors.lime,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, height: 1.35)),
    ],
  );
}

class _CareerTile extends StatelessWidget {
  const _CareerTile({
    required this.item,
    required this.isOwner,
    this.onHidden,
    this.onDelete,
  });

  final Map<String, dynamic> item;
  final bool isOwner;
  final ValueChanged<bool>? onHidden;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hidden = item['hidden'] == true;
    return Opacity(
      opacity: hidden ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: FutBoliaColors.cardDark.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name']?.toString() ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      PlayerProfileLabels.careerRole(item['role']?.toString()),
                      PlayerProfileLabels.formatDate(item['date']?.toString()),
                    ].where((e) => e.isNotEmpty).join(' · '),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: FutBoliaColors.danger,
                ),
              ),
            if (isOwner && onHidden != null)
              Column(
                children: [
                  Switch(
                    value: !hidden,
                    onChanged: (visible) => onHidden!(!visible),
                  ),
                  Text(
                    hidden ? 'Masqué' : 'Visible',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FriendActionButton extends StatelessWidget {
  const _FriendActionButton({
    required this.friendship,
    required this.loading,
    required this.onAdd,
    required this.onAccept,
  });

  final String? friendship;
  final bool loading;
  final VoidCallback onAdd;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    switch (friendship) {
      case 'friends':
        return const FbButton(
          label: 'Déjà amis',
          variant: FbButtonVariant.ghost,
          onPressed: null,
        );
      case 'pending_sent':
        return const FbButton(
          label: 'Demande envoyée',
          variant: FbButtonVariant.secondary,
          onPressed: null,
        );
      case 'pending_received':
        return FbButton(
          label: 'Accepter la demande',
          loading: loading,
          onPressed: onAccept,
        );
      default:
        return FbButton(
          label: 'Ajouter en ami',
          loading: loading,
          onPressed: onAdd,
        );
    }
  }
}
