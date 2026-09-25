import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class Mosque {
  const Mosque({required this.name, required this.lat, required this.lng, required this.distance, this.address});
  final String name;
  final double lat;
  final double lng;
  final double distance; // metres
  final String? address;
}

class MosqueService {
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// Mosques from OpenStreetMap within [radius] metres, nearest first.
  static Future<List<Mosque>> nearby(double lat, double lng, {int radius = 5000}) async {
    final query = '[out:json][timeout:25];'
        'nwr["amenity"="place_of_worship"]["religion"="muslim"](around:$radius,$lat,$lng);'
        'out center 60;';
    Object? lastError;
    for (final url in _endpoints) {
      try {
        final res = await http
            .post(Uri.parse(url), headers: {'User-Agent': 'BossMuslim/1.0'}, body: {'data': query})
            .timeout(const Duration(seconds: 30));
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        final elements = jsonDecode(utf8.decode(res.bodyBytes))['elements'] as List;
        final mosques = <Mosque>[];
        for (final e in elements) {
          final mlat = (e['lat'] ?? e['center']?['lat']) as num?;
          final mlng = (e['lon'] ?? e['center']?['lon']) as num?;
          if (mlat == null || mlng == null) continue;
          final tags = (e['tags'] ?? {}) as Map<String, dynamic>;
          final street = [tags['addr:housenumber'], tags['addr:street'], tags['addr:city']].whereType<String>().join(' ');
          mosques.add(Mosque(
            name: tags['name:en'] ?? tags['name'] ?? 'Mosque',
            lat: mlat.toDouble(),
            lng: mlng.toDouble(),
            distance: Geolocator.distanceBetween(lat, lng, mlat.toDouble(), mlng.toDouble()),
            address: street.isEmpty ? null : street,
          ));
        }
        mosques.sort((a, b) => a.distance.compareTo(b.distance));
        return mosques;
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Could not load mosques: $lastError');
  }
}
