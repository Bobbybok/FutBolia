import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/tokens/colors.dart';
import '../auth/application/auth_session.dart';
import '../pickup_matches/presentation/pickup_match_detail_screen.dart';
import '../tournaments/presentation/tournament_detail_screen.dart';
import 'geo_map_pins.dart';
import 'nearby_filters.dart';
import 'place_picker.dart';

/// Global nearby discovery: tournaments + pickups, Liste / Carte.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _viewTabs;
  GeoPoint? _center;
  List<Map<String, dynamic>> _tournaments = [];
  List<Map<String, dynamic>> _pickups = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _viewTabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _viewTabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_center == null) {
      setState(() {
        _tournaments = [];
        _pickups = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AuthSession>().api.discoveryNearby(
            lat: _center!.latitude,
            lng: _center!.longitude,
          );
      if (!mounted) return;
      setState(() {
        _tournaments = (data['tournaments'] as List? ?? [])
            .whereType<Map>()
            .map((e) => {...Map<String, dynamic>.from(e), 'kind': 'tournament'})
            .toList();
        _pickups = (data['pickups'] as List? ?? [])
            .whereType<Map>()
            .map((e) => {...Map<String, dynamic>.from(e), 'kind': 'pickup'})
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickZone() async {
    final place = await Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(builder: (_) => const ZonePickerScreen()),
    );
    if (place == null) return;
    setState(() => _center = place);
    await _load();
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final kind = item['kind']?.toString();
    final id = item['id']?.toString();
    if (id == null) return;
    if (kind == 'pickup') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PickupMatchDetailScreen(matchId: id)),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(tournamentId: id),
        ),
      );
    }
    await _load();
  }

  List<Map<String, dynamic>> get _all {
    final mixed = [..._tournaments, ..._pickups];
    mixed.sort((a, b) {
      final da = (a['distanceKm'] as num?)?.toDouble() ?? 9999;
      final db = (b['distanceKm'] as num?)?.toDouble() ?? 9999;
      return da.compareTo(db);
    });
    return mixed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FutBoliaColors.surfaceDark,
      appBar: AppBar(title: const Text('Près de moi')),
      body: Column(
        children: [
          const SizedBox(height: 8),
          NearbyFiltersBar(
            center: _center,
            onCenterChanged: (c) {
              setState(() => _center = c);
              _load();
            },
            onPickZone: _pickZone,
          ),
          TabBar(
            controller: _viewTabs,
            tabs: const [
              Tab(text: 'Liste'),
              Tab(text: 'Carte'),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: FutBoliaColors.danger)),
            ),
          Expanded(
            child: _center == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Utilise « Ma position » ou « Choisir une zone » pour voir les matchs et tournois à proximité.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  )
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _viewTabs,
                        children: [
                          _ListView(items: _all, onOpen: _open),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: GeoMapPins(
                              items: _all,
                              center: _center,
                              onOpen: _open,
                              height: MediaQuery.sizeOf(context).height * 0.55,
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.items, required this.onOpen});

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>) onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
        return const Center(
          child: Text(
            'Aucun événement trouvé.',
            style: TextStyle(color: Colors.white70),
          ),
        );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        final isPickup = item['kind'] == 'pickup';
        final dist = item['distanceKm'];
        return ListTile(
          tileColor: FutBoliaColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(
            isPickup ? Icons.sports_soccer : Icons.emoji_events,
            color: FutBoliaColors.lime,
          ),
          title: Text(
            isPickup
                ? (item['location']?.toString() ?? 'Match')
                : (item['name']?.toString() ?? 'Tournoi'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              isPickup ? 'Match' : 'Tournoi',
              if (dist != null) '$dist km',
              item['location']?.toString(),
            ].whereType<String>().join(' · '),
            style: const TextStyle(color: Colors.white70),
          ),
          onTap: () => onOpen(item),
        );
      },
    );
  }
}
