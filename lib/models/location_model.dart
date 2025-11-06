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

class RouteInfo {
  final List<LatLng> coordinates;
  final double distanceInMeters;
  final int travelTimeInSeconds;
  final String? trafficDelayInSeconds;

  RouteInfo({
    required this.coordinates,
    required this.distanceInMeters,
    required this.travelTimeInSeconds,
    this.trafficDelayInSeconds,
  });

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
}

