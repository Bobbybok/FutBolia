import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../design_system/tokens/colors.dart';
import 'directions.dart';

class MiniMapPreview extends StatelessWidget {
  const MiniMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label,
    this.height = 160,
    this.showDirections = true,
  });

  final double latitude;
  final double longitude;
  final String? label;
  final double height;
  final bool showDirections;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: height,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.futbolia.futbolia',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.location_on,
                        color: FutBoliaColors.lime,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (showDirections) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => showDirectionsSheet(
              context,
              latitude: latitude,
              longitude: longitude,
              label: label,
            ),
            icon: const Icon(Icons.directions),
            label: const Text('Y aller'),
          ),
        ],
      ],
    );
  }
}
