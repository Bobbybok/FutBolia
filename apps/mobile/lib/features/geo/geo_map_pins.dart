import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../design_system/tokens/colors.dart';
import 'nearby_filters.dart';

class GeoMapPins extends StatelessWidget {
  const GeoMapPins({
    super.key,
    required this.items,
    required this.onOpen,
    this.center,
    this.height = 320,
  });

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item) onOpen;
  final GeoPoint? center;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pins = items.where((e) => e['latitude'] != null && e['longitude'] != null);
    LatLng mapCenter;
    if (center != null) {
      mapCenter = LatLng(center!.latitude, center!.longitude);
    } else if (pins.isNotEmpty) {
      final first = pins.first;
      mapCenter = LatLng(
        (first['latitude'] as num).toDouble(),
        (first['longitude'] as num).toDouble(),
      );
    } else {
      mapCenter = const LatLng(46.6, 2.4);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: center != null || pins.isNotEmpty ? 11 : 5.5,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.futbolia.futbolia',
            ),
            MarkerLayer(
              markers: [
                for (final item in pins)
                  Marker(
                    point: LatLng(
                      (item['latitude'] as num).toDouble(),
                      (item['longitude'] as num).toDouble(),
                    ),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => onOpen(item),
                      child: Icon(
                        item['kind'] == 'pickup'
                            ? Icons.sports_soccer
                            : Icons.emoji_events,
                        color: FutBoliaColors.lime,
                        size: 36,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
