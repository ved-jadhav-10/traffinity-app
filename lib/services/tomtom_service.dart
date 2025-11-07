import 'dart:convert';
import 'package:flutter/material.dart';
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

  // Optimize waypoint order using TomTom Waypoint Optimization API
  Future<List<int>?> optimizeWaypoints({
    required List<Map<String, double>> waypoints,
    String travelMode = 'car',
    int? vehicleMaxSpeed,
  }) async {
    try {
      // Build the request body according to TomTom API specification
      final requestBody = {
        'waypoints': waypoints
            .map(
              (wp) => {
                'point': {'latitude': wp['lat'], 'longitude': wp['lng']},
              },
            )
            .toList(),
        'options': {
          'travelMode': travelMode,
          if (vehicleMaxSpeed != null) 'vehicleMaxSpeed': vehicleMaxSpeed,
        },
      };

      final url = Uri.parse(
        '$_baseUrl/routing/waypointoptimization/1?key=$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final optimizedOrder = (data['optimizedOrder'] as List)
            .map((e) => e as int)
            .toList();
        print('✅ Waypoint optimization successful: $optimizedOrder');
        return optimizedOrder;
      } else {
        print('❌ Waypoint optimization failed: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception('Failed to optimize waypoints: ${response.statusCode}');
      }
    } catch (e) {
      print('Error optimizing waypoints: $e');
      return null;
    }
  }

  // Calculate route between two points with optional waypoints
  Future<RouteInfo?> calculateRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    List<Map<String, dynamic>>? waypoints,
    bool optimizeWaypointOrder = false,
  }) async {
    try {
      // Optimize waypoint order if requested
      List<Map<String, dynamic>>? orderedWaypoints = waypoints;

      if (optimizeWaypointOrder && waypoints != null && waypoints.isNotEmpty) {
        print('🔄 Optimizing waypoint order...');

        // Convert waypoints to the format expected by optimization API
        final waypointsForOptimization = waypoints
            .map(
              (wp) => {'lat': wp['lat'] as double, 'lng': wp['lng'] as double},
            )
            .toList();

        // Get optimized order
        final optimizedOrder = await optimizeWaypoints(
          waypoints: waypointsForOptimization,
        );

        if (optimizedOrder != null && optimizedOrder.isNotEmpty) {
          // Reorder waypoints based on optimized order
          orderedWaypoints = optimizedOrder
              .map((index) => waypoints[index])
              .toList();
          print('✅ Waypoints reordered for optimal route');
        } else {
          print('⚠️ Optimization failed, using original order');
        }
      }

      // Build route points string: start:waypoint1:waypoint2:end
      String routePoints = '$startLat,$startLon';

      // Add waypoints if any
      if (orderedWaypoints != null && orderedWaypoints.isNotEmpty) {
        for (var waypoint in orderedWaypoints) {
          routePoints += ':${waypoint['lat']},${waypoint['lng']}';
        }
      }

      // Add destination
      routePoints += ':$endLat,$endLon';

      final url = Uri.parse(
        '$_baseUrl/routing/1/calculateRoute/$routePoints/json'
        '?key=$_apiKey&traffic=true&travelMode=car&sectionType=traffic'
        '&computeTravelTimeFor=all&instructionsType=text&language=en-US',
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

        // Parse traffic sections
        List<TrafficSection> trafficSections = [];
        if (route['sections'] != null) {
          final sections = route['sections'] as List;
          print('📊 Total sections received: ${sections.length}');
          for (var section in sections) {
            print('Section type: ${section['sectionType']}');
            if (section['sectionType'] == 'TRAFFIC') {
              print('🚦 Traffic section found: ${section['simpleCategory']}');
              trafficSections.add(TrafficSection.fromJson(section));
            }
          }
          print('✅ Parsed ${trafficSections.length} traffic sections');
        } else {
          print('⚠️ No sections in route response');
        }

        // Parse turn-by-turn instructions from guidance
        List<RouteInstruction> instructions = [];
        if (route['guidance'] != null &&
            route['guidance']['instructions'] != null) {
          final guidanceInstructions =
              route['guidance']['instructions'] as List;
          print(
            '🧭 Total instructions received: ${guidanceInstructions.length}',
          );
          for (var instruction in guidanceInstructions) {
            instructions.add(RouteInstruction.fromJson(instruction));
          }
          print('✅ Parsed ${instructions.length} navigation instructions');
        } else {
          print('⚠️ No guidance instructions in route response');
        }

        return RouteInfo(
          coordinates: coordinates,
          distanceInMeters: summary['lengthInMeters'].toDouble(),
          travelTimeInSeconds: summary['travelTimeInSeconds'],
          trafficDelayInSeconds: summary['trafficDelayInSeconds']?.toString(),
          trafficSections: trafficSections,
          instructions: instructions,
          historicTrafficTravelTimeInSeconds:
              summary['historicTrafficTravelTimeInSeconds'],
          liveTrafficIncidentsTravelTimeInSeconds:
              summary['liveTrafficIncidentsTravelTimeInSeconds'],
        );
      } else {
        throw Exception('Failed to calculate route: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calculating route: $e');
      return null;
    }
  }

  // Calculate multiple alternative routes
  Future<List<RouteInfo>> calculateAlternativeRoutes({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    List<Map<String, dynamic>>? waypoints,
    int maxAlternatives = 3,
  }) async {
    try {
      // Build route points string
      String routePoints = '$startLat,$startLon';

      if (waypoints != null && waypoints.isNotEmpty) {
        for (var waypoint in waypoints) {
          routePoints += ':${waypoint['lat']},${waypoint['lng']}';
        }
      }

      routePoints += ':$endLat,$endLon';

      final url = Uri.parse(
        '$_baseUrl/routing/1/calculateRoute/$routePoints/json'
        '?key=$_apiKey&traffic=true&travelMode=car&sectionType=traffic'
        '&computeTravelTimeFor=all&maxAlternatives=$maxAlternatives'
        '&alternativeType=anyRoute&instructionsType=text&language=en-US',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;

        List<RouteInfo> alternativeRoutes = [];

        for (int i = 0; i < routes.length; i++) {
          final route = routes[i];
          final summary = route['summary'];

          // Collect coordinates
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

          // Parse traffic sections
          List<TrafficSection> trafficSections = [];
          if (route['sections'] != null) {
            final sections = route['sections'] as List;
            for (var section in sections) {
              if (section['sectionType'] == 'TRAFFIC') {
                trafficSections.add(TrafficSection.fromJson(section));
              }
            }
          }

          // Parse turn-by-turn instructions
          List<RouteInstruction> instructions = [];
          if (route['guidance'] != null &&
              route['guidance']['instructions'] != null) {
            final guidanceInstructions =
                route['guidance']['instructions'] as List;
            for (var instruction in guidanceInstructions) {
              instructions.add(RouteInstruction.fromJson(instruction));
            }
          }

          print(
            'Route $i: ${trafficSections.length} traffic sections, ${instructions.length} instructions, delay: ${summary['trafficDelayInSeconds']}s',
          );

          alternativeRoutes.add(
            RouteInfo(
              coordinates: coordinates,
              distanceInMeters: summary['lengthInMeters'].toDouble(),
              travelTimeInSeconds: summary['travelTimeInSeconds'],
              trafficDelayInSeconds: summary['trafficDelayInSeconds']
                  ?.toString(),
              trafficSections: trafficSections,
              instructions: instructions,
              historicTrafficTravelTimeInSeconds:
                  summary['historicTrafficTravelTimeInSeconds'],
              liveTrafficIncidentsTravelTimeInSeconds:
                  summary['liveTrafficIncidentsTravelTimeInSeconds'],
              routeId: 'route_$i',
            ),
          );
        }

        return alternativeRoutes;
      } else {
        throw Exception('Failed to calculate routes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calculating alternative routes: $e');
      return [];
    }
  }

  // Calculate optimal departure time for next few hours
  Future<List<DepartureTimeOption>> calculateOptimalDepartureTimes({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    int hoursAhead = 6,
  }) async {
    List<DepartureTimeOption> options = [];
    final now = DateTime.now();

    for (int i = 0; i < hoursAhead; i++) {
      final departureTime = now.add(Duration(hours: i));

      try {
        String routePoints = '$startLat,$startLon:$endLat,$endLon';

        final url = Uri.parse(
          '$_baseUrl/routing/1/calculateRoute/$routePoints/json'
          '?key=$_apiKey&traffic=true&travelMode=car'
          '&departAt=${departureTime.toUtc().toIso8601String()}',
        );

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final route = data['routes'][0];
          final summary = route['summary'];

          options.add(
            DepartureTimeOption(
              departureTime: departureTime,
              travelTimeInSeconds: summary['travelTimeInSeconds'],
              trafficDelayInSeconds: summary['trafficDelayInSeconds'] ?? 0,
              distanceInMeters: summary['lengthInMeters'].toDouble(),
            ),
          );
        }
      } catch (e) {
        print('Error calculating departure time for hour $i: $e');
      }
    }

    return options;
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

  // Get live traffic incidents from TomTom Traffic Incidents API
  Future<List<TomTomIncident>> getLiveTrafficIncidents({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) async {
    try {
      // TomTom Traffic Incidents API v5
      final url = Uri.parse(
        '$_baseUrl/traffic/services/5/incidentDetails'
        '?key=$_apiKey'
        '&bbox=$minLon,$minLat,$maxLon,$maxLat'
        '&fields={incidents{type,geometry{type,coordinates},properties{iconCategory,magnitudeOfDelay,events{description,code,iconCategory},startTime,endTime,from,to,length,delay,roadNumbers,timeValidity}}}'
        '&language=en-US'
        '&categoryFilter=0,1,2,3,4,5,6,7,8,9,10,11,14',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final incidents = <TomTomIncident>[];

        if (data['incidents'] != null) {
          final incidentsList = data['incidents'] as List;
          print('🚦 Received ${incidentsList.length} live TomTom incidents');

          for (var incident in incidentsList) {
            try {
              incidents.add(TomTomIncident.fromJson(incident));
            } catch (e) {
              print('Error parsing incident: $e');
            }
          }
        }

        return incidents;
      } else {
        print('❌ Failed to get live incidents: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting live traffic incidents: $e');
      return [];
    }
  }

  // Get live traffic flow data (for drawing traffic polylines)
  Future<List<TrafficFlowSegment>> getLiveTrafficFlow({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    int zoom = 12,
  }) async {
    try {
      // TomTom Traffic Flow Segments API
      final url = Uri.parse(
        '$_baseUrl/traffic/services/4/flowSegmentData/absolute/$zoom/json'
        '?key=$_apiKey'
        '&point=${(minLat + maxLat) / 2},${(minLon + maxLon) / 2}'
        '&unit=KMPH',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final segments = <TrafficFlowSegment>[];

        if (data['flowSegmentData'] != null) {
          final flowData = data['flowSegmentData'];

          // Create segment from response
          segments.add(TrafficFlowSegment.fromJson(flowData));
          print('🚦 Received traffic flow data');
        }

        return segments;
      } else {
        print('❌ Failed to get traffic flow: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting traffic flow: $e');
      return [];
    }
  }
}

// Traffic Flow Segment Model
class TrafficFlowSegment {
  final double currentSpeed;
  final double freeFlowSpeed;
  final double confidence;
  final List<LatLng> coordinates;

  TrafficFlowSegment({
    required this.currentSpeed,
    required this.freeFlowSpeed,
    required this.confidence,
    required this.coordinates,
  });

  // Calculate traffic level color
  Color get trafficColor {
    if (coordinates.isEmpty) return Colors.grey;

    final ratio = currentSpeed / freeFlowSpeed;
    if (ratio >= 0.8) return const Color(0xFF06d6a0); // Green - Free flow
    if (ratio >= 0.5) return Colors.yellow; // Yellow - Moderate
    if (ratio >= 0.3) return Colors.orange; // Orange - Slow
    return Colors.red; // Red - Heavy traffic
  }

  String get trafficLevel {
    final ratio = currentSpeed / freeFlowSpeed;
    if (ratio >= 0.8) return 'free';
    if (ratio >= 0.5) return 'moderate';
    if (ratio >= 0.3) return 'slow';
    return 'heavy';
  }

  factory TrafficFlowSegment.fromJson(Map<String, dynamic> json) {
    List<LatLng> coords = [];

    if (json['coordinates'] != null) {
      final coordsData = json['coordinates']['coordinate'] as List;
      coords = coordsData
          .map((c) => LatLng(c['latitude'], c['longitude']))
          .toList();
    }

    return TrafficFlowSegment(
      currentSpeed: (json['currentSpeed'] ?? 0).toDouble(),
      freeFlowSpeed: (json['freeFlowSpeed'] ?? 1).toDouble(),
      confidence: (json['confidence'] ?? 0.5).toDouble(),
      coordinates: coords,
    );
  }
}

// TomTom Live Traffic Incident Model
class TomTomIncident {
  final String id;
  final String type;
  final LatLng location;
  final String iconCategory;
  final int magnitudeOfDelay;
  final String description;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? fromLocation;
  final String? toLocation;
  final int? lengthInMeters;
  final int? delayInSeconds;
  final List<String> roadNumbers;

  TomTomIncident({
    required this.id,
    required this.type,
    required this.location,
    required this.iconCategory,
    required this.magnitudeOfDelay,
    required this.description,
    this.startTime,
    this.endTime,
    this.fromLocation,
    this.toLocation,
    this.lengthInMeters,
    this.delayInSeconds,
    required this.roadNumbers,
  });

  // Map TomTom icon categories to your incident types
  String get incidentType {
    switch (iconCategory) {
      case '0': // Unknown
      case '1': // Accident
      case '2': // Fog
      case '3': // Dangerous conditions
      case '4': // Rain
      case '5': // Ice
      case '6': // Jam
      case '7': // Lane closed
      case '8': // Road closed
      case '9': // Road works
        return iconCategory == '9' ? 'roadwork' : 'accident';
      case '10': // Wind
      case '11': // Flooding
      case '14': // Broken down vehicle
        return 'accident';
      default:
        return 'accident';
    }
  }

  // Map magnitude of delay to severity
  String get severity {
    if (magnitudeOfDelay == 0) return 'Minor';
    if (magnitudeOfDelay == 1) return 'Minor';
    if (magnitudeOfDelay == 2) return 'Moderate';
    if (magnitudeOfDelay == 3) return 'Severe';
    return 'Critical'; // magnitude 4
  }

  String get iconPath {
    if (iconCategory == '9') {
      return 'assets/icons/roadwork.png';
    }
    return 'assets/icons/accident.png';
  }

  String get displayName {
    switch (iconCategory) {
      case '1':
        return 'Accident';
      case '6':
        return 'Traffic Jam';
      case '7':
        return 'Lane Closed';
      case '8':
        return 'Road Closed';
      case '9':
        return 'Road Work';
      case '11':
        return 'Flooding';
      case '14':
        return 'Broken Down Vehicle';
      default:
        return 'Traffic Incident';
    }
  }

  factory TomTomIncident.fromJson(Map<String, dynamic> json) {
    // Extract coordinates from geometry
    final geometry = json['geometry'];
    LatLng location;

    if (geometry['type'] == 'Point') {
      final coords = geometry['coordinates'] as List;
      location = LatLng(coords[1], coords[0]); // [lon, lat] to LatLng(lat, lon)
    } else {
      // For LineString or Polygon, use first coordinate
      final coords = (geometry['coordinates'] as List)[0] as List;
      location = LatLng(coords[1], coords[0]);
    }

    final properties = json['properties'];
    final events = properties['events'] as List;
    final firstEvent = events.isNotEmpty ? events[0] : null;

    return TomTomIncident(
      id: json['id'] ?? properties['id'] ?? '',
      type: geometry['type'] ?? 'Point',
      location: location,
      iconCategory: properties['iconCategory']?.toString() ?? '0',
      magnitudeOfDelay: properties['magnitudeOfDelay'] ?? 0,
      description: firstEvent?['description'] ?? 'Traffic incident',
      startTime: properties['startTime'] != null
          ? DateTime.parse(properties['startTime'])
          : null,
      endTime: properties['endTime'] != null
          ? DateTime.parse(properties['endTime'])
          : null,
      fromLocation: properties['from'],
      toLocation: properties['to'],
      lengthInMeters: properties['length'] != null
          ? (properties['length'] is int
                ? properties['length'] as int
                : (properties['length'] as num).round())
          : null,
      delayInSeconds: properties['delay'] != null
          ? (properties['delay'] is int
                ? properties['delay'] as int
                : (properties['delay'] as num).round())
          : null,
      roadNumbers:
          (properties['roadNumbers'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
