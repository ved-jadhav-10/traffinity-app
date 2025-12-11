import 'package:latlong2/latlong.dart';

class ParkingLayout {
  final String id;
  final String name;
  final String location; // Address text
  final double? latitude;
  final double? longitude;
  final String? ownerId;
  final DateTime createdAt;

  ParkingLayout({
    required this.id,
    required this.name,
    required this.location,
    this.latitude,
    this.longitude,
    this.ownerId,
    required this.createdAt,
  });

  // Get LatLng for map display
  LatLng? get coordinates {
    if (latitude != null && longitude != null) {
      return LatLng(latitude!, longitude!);
    }
    return null;
  }

  // Check if parking has valid coordinates for map display
  bool get hasCoordinates => latitude != null && longitude != null;

  // Factory constructor from JSON
  factory ParkingLayout.fromJson(Map<String, dynamic> json) {
    return ParkingLayout(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      ownerId: json['owner_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Copy with method for updates
  ParkingLayout copyWith({
    String? id,
    String? name,
    String? location,
    double? latitude,
    double? longitude,
    String? ownerId,
    DateTime? createdAt,
  }) {
    return ParkingLayout(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ParkingLayout(id: $id, name: $name, location: $location, coordinates: ${coordinates?.toString() ?? "None"})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParkingLayout && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
