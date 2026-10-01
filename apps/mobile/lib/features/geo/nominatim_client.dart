import 'dart:convert';
import 'package:http/http.dart' as http;

/// Free address search via OpenStreetMap Nominatim (no paid Google Places).
class NominatimPlace {
  const NominatimPlace({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

class NominatimClient {
  NominatimClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _userAgent = 'MatchArena/1.0 (contact: support@matcharena.app)';

  Future<List<NominatimPlace>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'json',
      'addressdetails': '0',
      'limit': '6',
      'countrycodes': 'fr',
    });
    final res = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent, 'Accept-Language': 'fr'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return [];
    final raw = jsonDecode(res.body);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) {
          final lat = double.tryParse(e['lat']?.toString() ?? '');
          final lon = double.tryParse(e['lon']?.toString() ?? '');
          final label = e['display_name']?.toString() ?? '';
          if (lat == null || lon == null || label.isEmpty) return null;
          return NominatimPlace(label: label, latitude: lat, longitude: lon);
        })
        .whereType<NominatimPlace>()
        .toList();
  }
}
