import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../state/app_state.dart';

class LocationException implements Exception {
  LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LocationService {
  static const _headers = {'User-Agent': 'BossMuslim/1.0 (prayer times app)'};

  /// Asks for permission if needed, then resolves the device position to a named place.
  static Future<SavedLocation> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Location services are turned off.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw LocationException('Location permission was denied. You can search for your city instead.');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)),
    );
    final name = await reverse(pos.latitude, pos.longitude);
    return SavedLocation(pos.latitude, pos.longitude, name);
  }

  static Future<String> reverse(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$lat',
        'lon': '$lng',
        'format': 'jsonv2',
        'zoom': '10',
        'accept-language': 'en',
      });
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      final a = (jsonDecode(res.body)['address'] ?? {}) as Map<String, dynamic>;
      final city = a['city'] ?? a['town'] ?? a['village'] ?? a['county'] ?? a['state_district'] ?? a['state'];
      final country = a['country'];
      return [city, country].whereType<String>().join(', ');
    } catch (_) {
      return '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}';
    }
  }

  static Future<List<SavedLocation>> search(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '8',
      'featureType': 'settlement',
      'accept-language': 'en',
    });
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    final list = jsonDecode(res.body) as List;
    return list.map((e) {
      final parts = (e['display_name'] as String).split(', ');
      final name = parts.length > 2 ? '${parts.first}, ${parts.last}' : parts.join(', ');
      return SavedLocation(double.parse(e['lat']), double.parse(e['lon']), name);
    }).toList();
  }
}
