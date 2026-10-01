import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;
  final String? label;
}

/// Position / zone only — lists are sorted nearest → farthest (no radius chips).
class NearbyFiltersBar extends StatelessWidget {
  const NearbyFiltersBar({
    super.key,
    required this.center,
    required this.onCenterChanged,
    required this.onPickZone,
  });

  final GeoPoint? center;
  final ValueChanged<GeoPoint?> onCenterChanged;
  final VoidCallback onPickZone;

  Future<void> _useMyPosition(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Position refusée. Tu peux choisir une zone manuellement.',
          ),
        ),
      );
      return;
    }
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Active la localisation du téléphone.')),
      );
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    onCenterChanged(
      GeoPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        label: 'Ma position',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _useMyPosition(context),
            icon: const Icon(Icons.my_location, size: 18),
            label: const Text('Ma position'),
          ),
          OutlinedButton.icon(
            onPressed: onPickZone,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Choisir une zone'),
          ),
          if (center != null)
            TextButton(
              onPressed: () => onCenterChanged(null),
              child: Text(
                center!.label ?? 'Zone active',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
