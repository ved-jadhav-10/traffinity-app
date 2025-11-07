import 'package:latlong2/latlong.dart';

class TrafficIncident {
  final String id;
  final String type; // JAM, ACCIDENT, ROAD_CLOSED, ROAD_WORK, etc.
  final String description;
  final LatLng location;
  final int delayInSeconds;
  final DateTime? startTime;
  final DateTime? endTime;
  final String severity; // CRITICAL, MAJOR, MODERATE, MINOR
  final String iconCategory;

  TrafficIncident({
    required this.id,
    required this.type,
    required this.description,
    required this.location,
    required this.delayInSeconds,
    this.startTime,
    this.endTime,
    required this.severity,
    required this.iconCategory,
  });

  factory TrafficIncident.fromJson(Map<String, dynamic> json) {
    // Extract location from geometry
    LatLng location = const LatLng(0, 0);
    if (json['geometry'] != null && json['geometry']['coordinates'] != null) {
      final coords = json['geometry']['coordinates'] as List;
      if (coords.isNotEmpty) {
        location = LatLng(coords[1], coords[0]); // [lon, lat] format
      }
    }

    return TrafficIncident(
      id: json['id']?.toString() ?? '',
      type: json['properties']?['incidentType'] ?? 'OTHER',
      description: json['properties']?['description'] ?? 'Traffic incident',
      location: location,
      delayInSeconds: json['properties']?['delay'] ?? 0,
      startTime: json['properties']?['startTime'] != null
          ? DateTime.parse(json['properties']['startTime'])
          : null,
      endTime: json['properties']?['endTime'] != null
          ? DateTime.parse(json['properties']['endTime'])
          : null,
      severity: json['properties']?['magnitudeOfDelay']?.toString() ?? 'MINOR',
      iconCategory: json['properties']?['iconCategory']?.toString() ?? '0',
    );
  }
}

class FlowSegmentData {
  final double currentSpeed; // Current speed in km/h
  final double freeFlowSpeed; // Free flow speed
  final double currentTravelTime; // Current travel time in seconds
  final double freeFlowTravelTime; // Free flow travel time
  final double confidence; // Data confidence (0-1)
  final bool roadClosure;

  FlowSegmentData({
    required this.currentSpeed,
    required this.freeFlowSpeed,
    required this.currentTravelTime,
    required this.freeFlowTravelTime,
    required this.confidence,
    required this.roadClosure,
  });

  double get congestionLevel {
    if (freeFlowSpeed == 0) return 0;
    return (freeFlowSpeed - currentSpeed) / freeFlowSpeed;
  }

  String get trafficStatus {
    if (roadClosure) return 'CLOSED';
    final level = congestionLevel;
    if (level < 0.25) return 'LIGHT';
    if (level < 0.5) return 'MODERATE';
    if (level < 0.75) return 'HEAVY';
    return 'SEVERE';
  }

  factory FlowSegmentData.fromJson(Map<String, dynamic> json) {
    return FlowSegmentData(
      currentSpeed: (json['currentSpeed'] as num?)?.toDouble() ?? 0.0,
      freeFlowSpeed: (json['freeFlowSpeed'] as num?)?.toDouble() ?? 0.0,
      currentTravelTime: (json['currentTravelTime'] as num?)?.toDouble() ?? 0.0,
      freeFlowTravelTime:
          (json['freeFlowTravelTime'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      roadClosure: json['roadClosure'] == true,
    );
  }
}

class NavigationState {
  final LatLng currentPosition;
  final int? currentInstructionIndex;
  final int distanceToNextTurn; // meters
  final int distanceRemaining; // meters
  final int timeRemaining; // seconds
  final bool isOnRoute;
  final double currentSpeed; // km/h
  final double currentHeading; // degrees
  final List<TrafficIncident> upcomingIncidents;

  NavigationState({
    required this.currentPosition,
    this.currentInstructionIndex,
    required this.distanceToNextTurn,
    required this.distanceRemaining,
    required this.timeRemaining,
    required this.isOnRoute,
    required this.currentSpeed,
    required this.currentHeading,
    this.upcomingIncidents = const [],
  });

  String get nextTurnDistance {
    if (distanceToNextTurn < 100) {
      return '${distanceToNextTurn.round()} m';
    } else if (distanceToNextTurn < 1000) {
      return '${(distanceToNextTurn / 100).round() * 100} m';
    } else {
      return '${(distanceToNextTurn / 1000).toStringAsFixed(1)} km';
    }
  }

  String get remainingDistance {
    if (distanceRemaining < 1000) {
      return '${distanceRemaining.round()} m';
    } else {
      return '${(distanceRemaining / 1000).toStringAsFixed(1)} km';
    }
  }

  String get eta {
    final now = DateTime.now();
    final arrival = now.add(Duration(seconds: timeRemaining));
    final hour = arrival.hour > 12
        ? arrival.hour - 12
        : (arrival.hour == 0 ? 12 : arrival.hour);
    final period = arrival.hour >= 12 ? 'PM' : 'AM';
    final minute = arrival.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
