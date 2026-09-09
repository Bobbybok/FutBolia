import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/fb_atmosphere.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_brand.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../auth/application/auth_session.dart';
import 'create_tournament_screen.dart';
import 'tournament_detail_screen.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _discover = [];
  List<Map<String, dynamic>> _mine = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthSession>().api;
      final discover = await api.listTournaments(query: _search.text.trim());
      final mine = await api.listTournaments(mine: true);
      if (!mounted) return;
      setState(() {
        _discover = discover;
        _mine = mine;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FutBoliaColors.surfaceDark,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateTournamentScreen()),
          );
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('CRÉER'),
      ),
      body: FbAtmosphere(
        safeArea: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  const Expanded(child: FbBrandHeader()),
                  Text(
                    'Tournois',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Découvrir'),
                Tab(text: 'Mes tournois'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Rechercher un tournoi…',
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.35),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: FutBoliaColors.lime),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: FutBoliaColors.lime, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: _load,
                  ),
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: FutBoliaColors.danger),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _TournamentList(
                          items: _discover,
                          emptyLabel:
                              'Aucun tournoi disponible pour le moment.',
                          onOpen: _open,
                          onRefresh: _load,
                        ),
                        _TournamentList(
                          items: _mine,
                          emptyLabel: 'Tu ne participes à aucun tournoi.',
                          onOpen: _open,
                          onRefresh: _load,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(Map<String, dynamic> tournament) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TournamentDetailScreen(tournamentId: tournament['id'] as String),
      ),
    );
    _load();
  }
}

class _TournamentList extends StatelessWidget {
  const _TournamentList({
    required this.items,
    required this.emptyLabel,
    required this.onOpen,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> items;
  final String emptyLabel;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                emptyLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final t = items[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onOpen(t),
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t['name']?.toString() ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: FutBoliaColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const FbBrandMark(size: 28),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${t['location'] ?? ''} · ${_formatDate(t['startsAt'])}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: FutBoliaColors.inkMuted,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FbBadge(
                          label: FrLabels.tournamentMode(t['mode']?.toString()),
                          background: FutBoliaColors.lime,
                          foreground: FutBoliaColors.ink,
                        ),
                        FbBadge(
                          label:
                              FrLabels.visibility(t['visibility']?.toString()),
                          background: const Color(0xFFF3F7F4),
                          foreground: FutBoliaColors.pitchDark,
                        ),
                        if (t['myRole'] != null)
                          FbBadge(
                            label:
                                FrLabels.memberRole(t['myRole']?.toString()),
                            background: FutBoliaColors.lime,
                            foreground: FutBoliaColors.ink,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final dt = DateTime.tryParse(value.toString())?.toLocal();
    if (dt == null) return value.toString();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
