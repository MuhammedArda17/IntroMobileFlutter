import 'dart:convert';
  import 'package:geolocator/geolocator.dart';
  import 'package:http/http.dart' as http;
  
  class LocationService {
    /// Vraagt toestemming en geeft de huidige GPS-positie terug.
    static Future<Position> getCurrentPosition() async {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Locatiediensten zijn uitgeschakeld op dit toestel.');
      }
  
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Locatiepermissie geweigerd.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Locatiepermissie permanent geweigerd. Pas dit aan in de instellingen.');
      }
  
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
    }
  
    /// Adres → coördinaten via Nominatim (OpenStreetMap, gratis).
    /// Geeft null terug als het adres niet gevonden wordt.
    static Future<Map<String, double>?> geocodeAddress(String address) async {
      final encoded = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=1',
      );
      try {
        final response = await http.get(url, headers: {
          'User-Agent': 'IntroMobileFlutter/1.0',
        });
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          if (data.isNotEmpty) {
            return {
              'latitude': double.parse(data[0]['lat'] as String),
              'longitude': double.parse(data[0]['lon'] as String),
            };
          }
        }
      } catch (_) {}
      return null;
    }
  
    /// Coördinaten → adres via Nominatim (reverse geocoding).
    static Future<String?> reverseGeocode(double lat, double lon) async {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
      );
      try {
        final response = await http.get(url, headers: {
          'User-Agent': 'IntroMobileFlutter/1.0',
        });
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          // Geef een korte weergave terug: straat + stad
          final address = data['address'] as Map<String, dynamic>?;
          if (address != null) {
            final road = address['road'] ?? '';
            final city = address['city'] ??
                address['town'] ??
                address['village'] ??
                address['municipality'] ??
                '';
            final postcode = address['postcode'] ?? '';
            if (road.isNotEmpty && city.isNotEmpty) {
              return '$road, $postcode $city'.trim();
            }
          }
          return data['display_name'] as String?;
        }
      } catch (_) {}
      return null;
    }
  
    /// Afstand in km tussen twee coördinaten (Haversine via Geolocator).
    static double distanceInKm(
        double lat1, double lon1, double lat2, double lon2) {
      return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
    }
  
    /// Geeft een leesbare afstandsstring terug, bv. "3.2 km" of "850 m".
    static String formatDistance(double km) {
      if (km < 1) {
        return '${(km * 1000).round()} m';
      }
      return '${km.toStringAsFixed(1)} km';
    }
  }