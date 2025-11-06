import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/tomtom_config.dart';
import '../models/location_model.dart';

class TomTomService {
  static final TomTomService _instance = TomTomService._internal();
  factory TomTomService() => _instance;
  TomTomService._internal();

  final String _apiKey = TomTomConfig.apiKey;
  final String _baseUrl = 'https://api.tomtom.com';

  // Search for locations with autocomplete
  Future<List<SearchResult>> searchLocations(
    String query, {
    double? lat,
    double? lon,
  }) async {
    if (query.isEmpty) return [];

    try {
      final url = Uri.parse(
        '$_baseUrl/search/2/search/$query.json?key=$_apiKey&limit=5'
        '${lat != null && lon != null ? '&lat=$lat&lon=$lon' : ''}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        return results
            .map((json) => SearchResult.fromTomTomJson(json))
            .toList();
      } else {
        throw Exception('Failed to search locations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching locations: $e');
      return [];
    }
  }

  // Calculate route between two points with optional waypoints
  Future<RouteInfo?> calculateRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    List<Map<String, dynamic>>? waypoints,
  }) async {
    try {
      // Build route points string: start:waypoint1:waypoint2:end
      String routePoints = '$startLat,$startLon';

      // Add waypoints if any
      if (waypoints != null && waypoints.isNotEmpty) {
        for (var waypoint in waypoints) {
          routePoints += ':${waypoint['lat']},${waypoint['lng']}';
        }
      }

      // Add destination
      routePoints += ':$endLat,$endLon';

      final url = Uri.parse(
        '$_baseUrl/routing/1/calculateRoute/$routePoints/json'
        '?key=$_apiKey&traffic=true&travelMode=car',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final summary = route['summary'];

        // Collect all points from all legs
        final legs = route['legs'] as List;
        List<LatLng> coordinates = [];

        for (var leg in legs) {
          final points = leg['points'] as List;
          coordinates.addAll(
            points.map((point) {
              return LatLng(point['latitude'], point['longitude']);
            }).toList(),
          );
        }

        return RouteInfo(
          coordinates: coordinates,
          distanceInMeters: summary['lengthInMeters'].toDouble(),
          travelTimeInSeconds: summary['travelTimeInSeconds'],
          trafficDelayInSeconds: summary['trafficDelayInSeconds']?.toString(),
        );
      } else {
        throw Exception('Failed to calculate route: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calculating route: $e');
      return null;
    }
  }

  // Search for nearby places by category
  Future<List<SearchResult>> searchNearbyPlaces({
    required double lat,
    required double lon,
    required String category,
    int radius = 5000, // 5km default
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/search/2/categorySearch/$category.json'
        '?key=$_apiKey&lat=$lat&lon=$lon&radius=$radius&limit=20',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        return results
            .map((json) => SearchResult.fromTomTomJson(json))
            .toList();
      } else {
        throw Exception(
          'Failed to search nearby places: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error searching nearby places: $e');
      return [];
    }
  }

  // Get reverse geocoding (address from coordinates)
  Future<String> getAddressFromCoordinates(double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/search/2/reverseGeocode/$lat,$lon.json?key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addresses = data['addresses'] as List;
        if (addresses.isNotEmpty) {
          return addresses[0]['address']['freeformAddress'] ?? '';
        }
      }
      return '';
    } catch (e) {
      print('Error getting address: $e');
      return '';
    }
  }
}
