import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../design_system/tokens/colors.dart';
import 'nominatim_client.dart';
import 'nearby_filters.dart';

/// Address search (Nominatim) + OSM map to confirm / nudge the pin.
class PlacePickerField extends StatefulWidget {
  const PlacePickerField({
    super.key,
    this.initialLabel,
    this.initialLatitude,
    this.initialLongitude,
    required this.onChanged,
  });

  final String? initialLabel;
  final double? initialLatitude;
  final double? initialLongitude;
  final void Function(GeoPoint? place) onChanged;

  @override
  State<PlacePickerField> createState() => _PlacePickerFieldState();
}

class _PlacePickerFieldState extends State<PlacePickerField> {
  final _search = TextEditingController();
  final _nominatim = NominatimClient();
  final _mapController = MapController();
  Timer? _debounce;
  List<NominatimPlace> _results = [];
  bool _searching = false;
  GeoPoint? _selected;
  static const _france = LatLng(46.6, 2.4);

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selected = GeoPoint(
        latitude: widget.initialLatitude!,
        longitude: widget.initialLongitude!,
        label: widget.initialLabel,
      );
      _search.text = widget.initialLabel ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      final results = await _nominatim.search(value);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    });
  }

  void _select(NominatimPlace place) {
    final point = GeoPoint(
      latitude: place.latitude,
      longitude: place.longitude,
      label: place.label,
    );
    setState(() {
      _selected = point;
      _results = [];
      _search.text = place.label;
    });
    widget.onChanged(point);
    _mapController.move(LatLng(place.latitude, place.longitude), 14);
  }

  void _onMapTap(TapPosition _, LatLng latlng) {
    final label = _selected?.label ?? _search.text.trim();
    final point = GeoPoint(
      latitude: latlng.latitude,
      longitude: latlng.longitude,
      label: label.isEmpty ? 'Point sélectionné' : label,
    );
    setState(() => _selected = point);
    widget.onChanged(point);
  }

  @override
  Widget build(BuildContext context) {
    final center = _selected != null
        ? LatLng(_selected!.latitude, _selected!.longitude)
        : _france;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            labelText: 'Rechercher une adresse / un lieu',
            hintText: 'Ex. Gymnase, ville…',
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search),
          ),
          onChanged: _onQueryChanged,
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: FutBoliaColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FutBoliaColors.lineDark),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _results.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: FutBoliaColors.lineDark),
              itemBuilder: (context, i) {
                final p = _results[i];
                return ListTile(
                  dense: true,
                  title: Text(
                    p.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  onTap: () => _select(p),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _selected == null ? 5.5 : 14,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.futbolia.futbolia',
                ),
                if (_selected != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          _selected!.latitude,
                          _selected!.longitude,
                        ),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: FutBoliaColors.lime,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _selected == null
              ? 'Choisis un résultat puis ajuste le pin sur la carte.'
              : (_selected!.label ?? 'Lieu sélectionné'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
        ),
      ],
    );
  }
}

/// Full-screen zone picker (for discovery filters without GPS).
class ZonePickerScreen extends StatefulWidget {
  const ZonePickerScreen({super.key});

  @override
  State<ZonePickerScreen> createState() => _ZonePickerScreenState();
}

class _ZonePickerScreenState extends State<ZonePickerScreen> {
  GeoPoint? _place;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choisir une zone')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PlacePickerField(
            onChanged: (p) => setState(() => _place = p),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _place == null
                ? null
                : () => Navigator.of(context).pop(_place),
            child: const Text('Utiliser cette zone'),
          ),
        ],
      ),
    );
  }
}
