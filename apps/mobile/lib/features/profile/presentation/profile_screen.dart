import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_atmosphere.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_brand.dart';
import '../../../design_system/components/fb_button.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import '../../auth/presentation/verify_email_screen.dart';
import '../../friends/friends_screen.dart';
import '../player_profile_labels.dart';
import '../widgets/player_avatar.dart';
import '../career_actions.dart';
import 'public_profile_screen.dart';
import 'settings_tab.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Non connecté')));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: FutBoliaColors.surfaceDark,
        body: FbAtmosphere(
          safeArea: true,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    const Expanded(child: FbBrandHeader()),
                    Text(
                      'Profil',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Profil'),
                  Tab(text: 'Amis'),
                  Tab(text: 'Réglages'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _ProfileEditTab(),
                    FriendsScreen(embedded: true),
                    SettingsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileEditTab extends StatefulWidget {
  const _ProfileEditTab();

  @override
  State<_ProfileEditTab> createState() => _ProfileEditTabState();
}

class _ProfileEditTabState extends State<_ProfileEditTab>
    with AutomaticKeepAliveClientMixin {
  final _city = TextEditingController();
  final _bio = TextEditingController();
  final _firstName = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  bool _loading = false;
  bool _initialized = false;
  bool _careerLoading = true;
  String? _foot;
  String? _experience;
  int? _sinceYear;
  List<String> _positions = [];
  List<String> _availability = [];
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _tournaments = [];
  List<Map<String, dynamic>> _matches = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthSession>().user;
    if (user != null) {
      _hydrateFromUser();
      _initialized = true;
      _loadCareer();
    }
  }

  void _hydrateFromUser() {
    final user = context.read<AuthSession>().user;
    if (user == null) return;
    _city.text = user.city ?? '';
    _bio.text = user.bio ?? '';
    _firstName.text = user.firstName ?? '';
    _height.text = user.heightCm?.toString() ?? '';
    _weight.text = user.weightKg?.toString() ?? '';
    _foot = user.strongFoot;
    _experience = user.experienceLevel;
    _sinceYear = user.playingSinceYear;
    _positions = List<String>.from(user.positions);
    _availability = List<String>.from(user.availability);
  }

  Future<void> _loadCareer() async {
    final user = context.read<AuthSession>().user;
    if (user == null) return;
    setState(() => _careerLoading = true);
    try {
      final data = await context.read<AuthSession>().api.getPublicUser(user.id);
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(data['stats'] as Map? ?? {});
        _tournaments = _asMaps(data['tournaments']);
        _matches = _asMaps(data['matches']);
        _careerLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _careerLoading = false);
    }
  }

  List<Map<String, dynamic>> _asMaps(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  void dispose() {
    _city.dispose();
    _bio.dispose();
    _firstName.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 82,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _loading = true);
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final name = picked.name.toLowerCase();
      final mime = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      await context.read<AuthSession>().uploadAvatar(
            bytes: bytes,
            filename: picked.name.isEmpty ? 'avatar.jpg' : picked.name,
            contentType: mime,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo mise à jour')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ajouter la photo')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleCareer(Map<String, dynamic> item, bool hidden) async {
    try {
      final career = await context.read<AuthSession>().api.hideCareerItem(
            itemType: item['kind']?.toString() ?? 'tournament',
            itemId: item['id']?.toString() ?? '',
            hidden: hidden,
          );
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(career['stats'] as Map? ?? _stats);
        _tournaments = _asMaps(career['tournaments']);
        _matches = _asMaps(career['matches']);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteCareer(Map<String, dynamic> item) async {
    final user = context.read<AuthSession>().user;
    if (user == null) return;
    final choice = await confirmCareerDelete(
      context,
      item,
      isOwnProfile: true,
    );
    if (choice == null || !mounted) return;
    try {
      final career = await applyCareerDelete(
        api: context.read<AuthSession>().api,
        item: item,
        choice: choice,
        profileUserId: user.id,
      );
      if (!mounted) return;
      if (career != null) {
        setState(() {
          _stats = Map<String, dynamic>.from(career['stats'] as Map? ?? _stats);
          _tournaments = _asMaps(career['tournaments']);
          _matches = _asMaps(career['matches']);
        });
      } else {
        await _loadCareer();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _togglePosition(String code) {
    setState(() {
      if (_positions.contains(code)) {
        _positions = _positions.where((e) => e != code).toList();
      } else if (_positions.length < 5) {
        _positions = [..._positions, code];
      }
    });
  }

  void _toggleAvailability(String code) {
    setState(() {
      if (_availability.contains(code)) {
        _availability = _availability.where((e) => e != code).toList();
      } else {
        _availability = [..._availability, code];
      }
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthSession>().updateProfile({
        'firstName':
            _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        'positions': _positions,
        'strongFoot': _foot,
        'heightCm': asInt(_height.text.trim()),
        'weightKg': asInt(_weight.text.trim()),
        'experienceLevel': _experience,
        'playingSinceYear': _sinceYear,
        'availability': _availability,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour')),
      );
    } catch (_) {
      if (!mounted) return;
      final msg =
          context.read<AuthSession>().errorMessage ?? 'Mise à jour impossible';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final session = context.watch<AuthSession>();
    final user = session.user;
    if (user == null) {
      return const Center(child: Text('Non connecté'));
    }
    final yearNow = DateTime.now().year;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: FutBoliaColors.cardDark.withValues(alpha: 0.72),
            border: Border.all(
              color: FutBoliaColors.lime.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              PlayerAvatar(
                userId: user.id,
                avatarUrl: user.avatarUrl,
                onTap: _loading ? null : _pickPhoto,
              ),
              const SizedBox(height: 12),
              Text(
                user.displayPseudo,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => openPublicProfile(context, user.id),
                child: const Text('Voir mon profil public'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _MiniStats(stats: _stats, loading: _careerLoading),
        const SizedBox(height: 16),
        FbBadge(
          label: user.emailVerified ? 'E-MAIL VÉRIFIÉ' : 'E-MAIL À VÉRIFIER',
          background:
              user.emailVerified ? FutBoliaColors.lime : FutBoliaColors.clay,
          foreground: user.emailVerified
              ? FutBoliaColors.ink
              : Colors.white,
        ),
        if (!user.emailVerified) ...[
          const SizedBox(height: 12),
          FbButton(
            label: 'Vérifier mon e-mail',
            variant: FbButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
              );
            },
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _firstName,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Prénom (optionnel)'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _city,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Ville'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _bio,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 22),
        const _SectionTitle('Postes (max 5, dans l’ordre de préférence)'),
        const SizedBox(height: 8),
        if (_positions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _positions
                  .asMap()
                  .entries
                  .map(
                    (e) =>
                        '${e.key + 1}. ${PlayerProfileLabels.position(e.value)}',
                  )
                  .join('  ·  '),
              style: const TextStyle(color: FutBoliaColors.lime),
            ),
          ),
        ...PlayerProfileLabels.positionGroups.entries.map((group) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.key,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in group.value)
                      FilterChip(
                        label: Text(
                          _positions.contains(item.$1)
                              ? '${_positions.indexOf(item.$1) + 1}. ${item.$2}'
                              : item.$2,
                        ),
                        selected: _positions.contains(item.$1),
                        tooltip: item.$3,
                        onSelected: (_) => _togglePosition(item.$1),
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        const _SectionTitle('Pied fort'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in PlayerProfileLabels.feet.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _foot == entry.key,
                onSelected: (_) => setState(() {
                  _foot = _foot == entry.key ? null : entry.key;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Mensurations'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _height,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Taille (cm)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _weight,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Poids (kg)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Expérience'),
        const SizedBox(height: 8),
        DropdownMenu<String>(
          initialSelection: _experience ?? '',
          dropdownMenuEntries: [
            const DropdownMenuEntry(value: '', label: 'Non renseigné'),
            ...PlayerProfileLabels.experience.entries.map(
              (e) => DropdownMenuEntry(value: e.key, label: e.value),
            ),
          ],
          label: const Text('Palier'),
          expandedInsets: EdgeInsets.zero,
          onSelected: (value) => setState(
            () => _experience = (value == null || value.isEmpty) ? null : value,
          ),
        ),
        const SizedBox(height: 12),
        DropdownMenu<int>(
          initialSelection: _sinceYear ?? 0,
          dropdownMenuEntries: [
            const DropdownMenuEntry(value: 0, label: 'Non renseigné'),
            for (var year = yearNow; year >= 1970; year--)
              DropdownMenuEntry(value: year, label: '$year'),
          ],
          label: const Text('Je joue depuis'),
          expandedInsets: EdgeInsets.zero,
          onSelected: (value) => setState(
            () => _sinceYear = (value == null || value == 0) ? null : value,
          ),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Disponibilités'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in PlayerProfileLabels.availability.entries)
              FilterChip(
                label: Text(entry.value),
                selected: _availability.contains(entry.key),
                onSelected: (_) => _toggleAvailability(entry.key),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FbButton(label: 'Enregistrer', loading: _loading, onPressed: _save),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(child: _SectionTitle('Tournois')),
            Text(
              '${_tournaments.length}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Masquer le cache du profil public. Supprimer le retire de ton profil ; orga et admin peuvent aussi supprimer l’événement.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (_careerLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_tournaments.isEmpty)
          const Text(
            'Pas encore de tournoi.',
            style: TextStyle(color: Colors.white70),
          )
        else
          ..._tournaments.map(
            (item) => _CareerEditTile(
              item: item,
              onHidden: (hidden) => _toggleCareer(item, hidden),
              onDelete: () => _deleteCareer(item),
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: _SectionTitle('Matchs')),
            Text(
              '${_matches.length}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_careerLoading)
          const SizedBox.shrink()
        else if (_matches.isEmpty)
          const Text(
            'Pas encore de match.',
            style: TextStyle(color: Colors.white70),
          )
        else
          ..._matches.map(
            (item) => _CareerEditTile(
              item: item,
              onHidden: (hidden) => _toggleCareer(item, hidden),
              onDelete: () => _deleteCareer(item),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MiniStats extends StatelessWidget {
  const _MiniStats({required this.stats, required this.loading});

  final Map<String, dynamic> stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, dynamic value) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: FutBoliaColors.cardDark.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: FutBoliaColors.lime.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            children: [
              Text(
                loading ? '—' : '${value ?? 0}',
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

    return Row(
      children: [
        cell('Tournois', stats['tournaments']),
        cell('Matchs', stats['matches']),
        cell('Orga', stats['asOrganizer']),
        cell('Cap.', stats['asCaptain']),
      ],
    );
  }
}

class _CareerEditTile extends StatelessWidget {
  const _CareerEditTile({
    required this.item,
    required this.onHidden,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final ValueChanged<bool> onHidden;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hidden = item['hidden'] == true;
    final canAct = !item.containsKey('canRemoveFromProfile') ||
        careerCanRemoveFromProfile(item) ||
        careerCanDeleteEvent(item);
    return Opacity(
      opacity: hidden ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
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
            if (canAct)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: FutBoliaColors.danger),
              ),
            Column(
              children: [
                Switch(
                  value: !hidden,
                  onChanged: (visible) => onHidden(!visible),
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
