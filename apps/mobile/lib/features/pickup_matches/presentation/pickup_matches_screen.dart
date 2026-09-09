import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/i18n/fr_labels.dart';
import '../../../design_system/components/fb_badge.dart';
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
      appBar: AppBar(
        title: const Text('Matchs'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: FutBoliaColors.pitchDark,
          tabs: const [
            Tab(text: 'Ouverts'),
            Tab(text: 'Mes matchs'),
          ],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const CreatePickupMatchScreen(),
            ),
          );
          if (created == true) _load();
        },
        backgroundColor: FutBoliaColors.pitch,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
      ),
      body: Column(
        children: [
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
                        emptyLabel: 'Aucun match public ouvert pour le moment.',
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
                      color: FutBoliaColors.inkMuted,
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final m = items[index];
          final capacity = m['capacity'] ?? ((m['playersPerTeam'] as int? ?? 0) * 2);
          final membersCount = m['membersCount'] ?? 0;
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onOpen(m),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['location']?.toString() ?? 'Match',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(m['scheduledAt']),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: FutBoliaColors.inkMuted,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FbBadge(
                          label: FrLabels.matchStatus(m['status']?.toString()),
                        ),
                        FbBadge(
                          label: FrLabels.visibility(m['visibility']?.toString()),
                          background: const Color(0xFFE3F2FD),
                        ),
                        FbBadge(
                          label: '$membersCount / $capacity',
                          background: const Color(0xFFE8F5E9),
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
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return dt.toLocal().toString().substring(0, 16);
  }
}
