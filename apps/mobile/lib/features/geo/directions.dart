import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens installed navigation apps via free deep links (no Maps SDK).
Future<void> showDirectionsSheet(
  BuildContext context, {
  required double latitude,
  required double longitude,
  String? label,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Google Maps'),
              onTap: () {
                Navigator.pop(ctx);
                _open(
                  Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.navigation_outlined),
              title: const Text('Waze'),
              onTap: () {
                Navigator.pop(ctx);
                _open(
                  Uri.parse(
                    'https://waze.com/ul?ll=$latitude%2C$longitude&navigate=yes',
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.apple),
              title: const Text('Apple Plans'),
              onTap: () {
                Navigator.pop(ctx);
                final q = label != null && label.isNotEmpty
                    ? Uri.encodeComponent(label)
                    : '$latitude,$longitude';
                _open(
                  Uri.parse(
                    'https://maps.apple.com/?daddr=$q&ll=$latitude,$longitude',
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> _open(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
