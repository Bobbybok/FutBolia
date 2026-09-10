import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../../design_system/components/fb_atmosphere.dart';
import '../../../design_system/components/fb_badge.dart';
import '../../../design_system/components/fb_brand.dart';
import '../../../design_system/tokens/colors.dart';
import '../../auth/application/auth_session.dart';
import 'create_pickup_match_screen.dart';
import 'pickup_match_detail_screen.dart';

class PickupMatchesScreen extends StatefulWidget {
  const PickupMatchesScreen({super.key});

  @override
  State<PickupMatchesScreen> createState() => _PickupMatchesScreenState();
}

class _PickupMatchesScreenState extends State<PickupMatchesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthSession>().api;
      final discover = await api.listPickupMatches();
      final mine = await api.listPickupMatches(mine: true);
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

  Future<void> _open(Map<String, dynamic> match) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PickupMatchDetailScreen(
          matchId: match['id'] as String,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FutBoliaColors.surfaceDark,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const CreatePickupMatchScreen(),
            ),
          );
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('CRÉER'),
      ),
      body: FbAtmosphere(
        asset: 'assets/images/bg_pitch.jpg',
        safeArea: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  const Expanded(child: FbBrandHeader()),
                  Text(
                    'Matchs',
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
                Tab(text: 'Ouverts'),
                Tab(text: 'Mes matchs'),
              ],
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
                        _PickupMatchList(
                          items: _discover,
                          emptyLabel:
                              'Aucun match public ouvert pour le moment.',
                          onOpen: _open,
                          onRefresh: _load,
                        ),
                        _PickupMatchList(
                          items: _mine,
                          emptyLabel: 'Tu ne participes à aucun match.',
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
}

class _PickupMatchList extends StatelessWidget {
  const _PickupMatchList({
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final m = items[index];
          final capacity =
              m['capacity'] ?? ((m['playersPerTeam'] as int? ?? 0) * 2);
          final membersCount = m['membersCount'] ?? 0;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onOpen(m),
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FutBoliaColors.cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: FutBoliaColors.lineDark),
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
                            m['location']?.toString() ?? 'Match',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: FutBoliaColors.inkDark,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const FbBrandMark(size: 28),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(m['scheduledAt']),
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
                          label: FrLabels.matchStatus(m['status']?.toString()),
                          background: FutBoliaColors.lime,
                          foreground: FutBoliaColors.ink,
                        ),
                        FbBadge(
                          label:
                              FrLabels.visibility(m['visibility']?.toString()),
                          background: FutBoliaColors.badgeSoft,
                          foreground: FutBoliaColors.inkDark,
                        ),
                        FbBadge(
                          label: '$membersCount / $capacity',
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
    if (value == null) return 'Date inconnue';
    final dt = DateTime.tryParse(value.toString())?.toLocal();
    if (dt == null) return value.toString();
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} · $hour:$minute';
  }
}
