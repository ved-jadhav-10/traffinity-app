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
      name: json['poi']?['name'] ?? address['freeformAddress'] ?? 'Unknown Location',
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
  final int trafficDelayInSeconds;
  final double simpleCategory; // 0-4 representing traffic level
  final double currentSpeed;
  final double freeFlowSpeed;

  TrafficSection({
    required this.startPointIndex,
    required this.endPointIndex,
    required this.travelTimeInSeconds,
    required this.trafficDelayInSeconds,
    required this.simpleCategory,
    required this.currentSpeed,
    required this.freeFlowSpeed,
  });

  String get trafficLevel {
    if (simpleCategory <= 1) return 'Light';
    if (simpleCategory <= 2) return 'Moderate';
    if (simpleCategory <= 3) return 'Heavy';
    return 'Severe';
  }

  factory TrafficSection.fromJson(Map<String, dynamic> json) {
    return TrafficSection(
      startPointIndex: json['startPointIndex'] ?? 0,
      endPointIndex: json['endPointIndex'] ?? 0,
      travelTimeInSeconds: json['travelTimeInSeconds'] ?? 0,
      trafficDelayInSeconds: json['trafficDelayInSeconds'] ?? 0,
      simpleCategory: (json['simpleCategory'] as num?)?.toDouble() ?? 0.0,
      currentSpeed: (json['currentSpeed'] as num?)?.toDouble() ?? 0.0,
      freeFlowSpeed: (json['freeFlowSpeed'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RouteInfo {
  final List<LatLng> coordinates;
  final double distanceInMeters;
  final int travelTimeInSeconds;
  final String? trafficDelayInSeconds;
  final List<TrafficSection> trafficSections;
  final int? historicTrafficTravelTimeInSeconds;
  final int? liveTrafficIncidentsTravelTimeInSeconds;
  final String routeId;

  RouteInfo({
    required this.coordinates,
    required this.distanceInMeters,
    required this.travelTimeInSeconds,
    this.trafficDelayInSeconds,
    this.trafficSections = const [],
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
    if (trafficSections.isEmpty) return 'Unknown';
    
    // Calculate average traffic level
    final avgCategory = trafficSections
        .map((s) => s.simpleCategory)
        .reduce((a, b) => a + b) / trafficSections.length;
    
    if (avgCategory <= 1) return 'Light';
    if (avgCategory <= 2) return 'Moderate';
    if (avgCategory <= 3) return 'Heavy';
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


