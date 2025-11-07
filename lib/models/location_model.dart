import 'package:latlong2/latlong.dart';

class LocationModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? category;
  final DateTime? createdAt;

  LocationModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.category,
    this.createdAt,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      category: json['category'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'category': category,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class SearchResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? category;

  SearchResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.category,
  });

  factory SearchResult.fromTomTomJson(Map<String, dynamic> json) {
    final position = json['position'];
    final address = json['address'];

    return SearchResult(
      name:
          json['poi']?['name'] ??
          address['freeformAddress'] ??
          'Unknown Location',
      address: address['freeformAddress'] ?? '',
      latitude: position['lat'],
      longitude: position['lon'],
      category: json['poi']?['categories']?[0] ?? json['type'],
    );
  }
}

class TrafficSection {
  final int startPointIndex;
  final int endPointIndex;
  final int travelTimeInSeconds;
  final int delayInSeconds; // Correct field name from TomTom API
  final String simpleCategory; // Type: JAM, ROAD_WORK, ROAD_CLOSURE, OTHER
  final double effectiveSpeedInKmh; // Correct field name from TomTom API

  TrafficSection({
    required this.startPointIndex,
    required this.endPointIndex,
    required this.travelTimeInSeconds,
    required this.delayInSeconds,
    required this.simpleCategory,
    required this.effectiveSpeedInKmh,
  });

  String get trafficLevel {
    // Map incident types to traffic levels
    switch (simpleCategory.toUpperCase()) {
      case 'JAM':
        return 'Heavy';
      case 'ROAD_WORK':
        return 'Moderate';
      case 'ROAD_CLOSURE':
        return 'Severe';
      case 'OTHER':
        return 'Light';
      default:
        return 'Unknown';
    }
  }

  factory TrafficSection.fromJson(Map<String, dynamic> json) {
    return TrafficSection(
      startPointIndex: json['startPointIndex'] ?? 0,
      endPointIndex: json['endPointIndex'] ?? 0,
      travelTimeInSeconds: json['travelTimeInSeconds'] ?? 0,
      delayInSeconds: json['delayInSeconds'] ?? 0,
      simpleCategory: json['simpleCategory']?.toString() ?? 'OTHER',
      effectiveSpeedInKmh:
          (json['effectiveSpeedInKmh'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RouteInfo {
  final List<LatLng> coordinates;
  final double distanceInMeters;
  final int travelTimeInSeconds;
  final String? trafficDelayInSeconds;
  final List<TrafficSection> trafficSections;
  final List<RouteInstruction> instructions; // Turn-by-turn instructions
  final int? historicTrafficTravelTimeInSeconds;
  final int? liveTrafficIncidentsTravelTimeInSeconds;
  final String routeId;

  RouteInfo({
    required this.coordinates,
    required this.distanceInMeters,
    required this.travelTimeInSeconds,
    this.trafficDelayInSeconds,
    this.trafficSections = const [],
    this.instructions = const [],
    this.historicTrafficTravelTimeInSeconds,
    this.liveTrafficIncidentsTravelTimeInSeconds,
    String? routeId,
  }) : routeId = routeId ?? DateTime.now().millisecondsSinceEpoch.toString();

  String get formattedDistance {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  String get formattedTime {
    final minutes = travelTimeInSeconds ~/ 60;
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    }
  }

  String get trafficInfo {
    if (trafficDelayInSeconds != null) {
      final delay = int.tryParse(trafficDelayInSeconds!) ?? 0;
      if (delay > 0) {
        final delayMinutes = delay ~/ 60;
        return '+$delayMinutes min delay';
      }
    }
    return 'No delays';
  }

  int get trafficDelaySeconds {
    return int.tryParse(trafficDelayInSeconds ?? '0') ?? 0;
  }

  String get overallTrafficLevel {
    // If we have traffic sections, use them for detailed analysis
    if (trafficSections.isNotEmpty) {
      // Determine worst traffic level from all sections
      bool hasRoadClosure = false;
      bool hasJam = false;
      bool hasRoadWork = false;

      for (var section in trafficSections) {
        switch (section.simpleCategory.toUpperCase()) {
          case 'ROAD_CLOSURE':
            hasRoadClosure = true;
            break;
          case 'JAM':
            hasJam = true;
            break;
          case 'ROAD_WORK':
            hasRoadWork = true;
            break;
        }
      }

      if (hasRoadClosure) return 'Severe';
      if (hasJam) return 'Heavy';
      if (hasRoadWork) return 'Moderate';
      return 'Light';
    }

    // Fallback: Use traffic delay from summary if no sections available
    final delayMinutes = trafficDelaySeconds / 60;

    if (delayMinutes == 0) return 'Light';
    if (delayMinutes < 5) return 'Light';
    if (delayMinutes < 10) return 'Moderate';
    if (delayMinutes < 20) return 'Heavy';
    return 'Severe';
  }
}

class DepartureTimeOption {
  final DateTime departureTime;
  final int travelTimeInSeconds;
  final int trafficDelayInSeconds;
  final double distanceInMeters;

  DepartureTimeOption({
    required this.departureTime,
    required this.travelTimeInSeconds,
    required this.trafficDelayInSeconds,
    required this.distanceInMeters,
  });

  String get formattedTime {
    final hour = departureTime.hour > 12
        ? departureTime.hour - 12
        : (departureTime.hour == 0 ? 12 : departureTime.hour);
    final period = departureTime.hour >= 12 ? 'PM' : 'AM';
    final minute = departureTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String get formattedDuration {
    final minutes = travelTimeInSeconds ~/ 60;
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    }
  }

  int get totalTimeInSeconds => travelTimeInSeconds + trafficDelayInSeconds;
}

class RouteInstruction {
  final String
  instruction; // The instruction text (e.g., "Turn right onto Main St")
  final String
  maneuver; // Type of maneuver (e.g., "TURN_RIGHT", "TURN_LEFT", "STRAIGHT")
  final int distanceInMeters; // Distance to this instruction
  final int travelTimeInSeconds; // Time to reach this instruction
  final LatLng? point; // GPS coordinate of the instruction point
  final String? roadNumbers; // Road/highway numbers
  final String? street; // Street name
  final int? exitNumber; // Exit number for roundabouts/highways

  RouteInstruction({
    required this.instruction,
    required this.maneuver,
    required this.distanceInMeters,
    required this.travelTimeInSeconds,
    this.point,
    this.roadNumbers,
    this.street,
    this.exitNumber,
  });

  String get formattedDistance {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  factory RouteInstruction.fromJson(Map<String, dynamic> json) {
    LatLng? instructionPoint;
    if (json['point'] != null) {
      instructionPoint = LatLng(
        json['point']['latitude'],
        json['point']['longitude'],
      );
    }

    return RouteInstruction(
      instruction: json['message'] ?? json['instruction'] ?? 'Continue',
      maneuver: json['maneuver'] ?? 'STRAIGHT',
      distanceInMeters: json['routeOffsetInMeters'] ?? 0,
      travelTimeInSeconds: json['travelTimeInSeconds'] ?? 0,
      point: instructionPoint,
      roadNumbers: json['roadNumbers']?.join(', '),
      street: json['street'],
      exitNumber: json['exitNumber'],
    );
  }
}
