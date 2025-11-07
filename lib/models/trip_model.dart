class Trip {
  final String id;
  final String userId;
  final String tripName;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String startLocationName;
  final double startLocationLat;
  final double startLocationLon;
  final String endLocationName;
  final double endLocationLat;
  final double endLocationLon;
  final double distanceKm;
  final String transportType; // car, bike, train, bus, plane
  final String status; // planned, in_progress, completed
  final DateTime createdAt;
  final DateTime updatedAt;

  Trip({
    required this.id,
    required this.userId,
    required this.tripName,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.startLocationName,
    required this.startLocationLat,
    required this.startLocationLon,
    required this.endLocationName,
    required this.endLocationLat,
    required this.endLocationLon,
    required this.distanceKm,
    required this.transportType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tripName: json['trip_name'] as String,
      description: json['description'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      startLocationName: json['start_location_name'] as String,
      startLocationLat: (json['start_location_lat'] as num).toDouble(),
      startLocationLon: (json['start_location_lon'] as num).toDouble(),
      endLocationName: json['end_location_name'] as String,
      endLocationLat: (json['end_location_lat'] as num).toDouble(),
      endLocationLon: (json['end_location_lon'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num).toDouble(),
      transportType: json['transport_type'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'trip_name': tripName,
      'description': description,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'start_location_name': startLocationName,
      'start_location_lat': startLocationLat,
      'start_location_lon': startLocationLon,
      'end_location_name': endLocationName,
      'end_location_lat': endLocationLat,
      'end_location_lon': endLocationLon,
      'distance_km': distanceKm,
      'transport_type': transportType,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Trip copyWith({
    String? id,
    String? userId,
    String? tripName,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? startLocationName,
    double? startLocationLat,
    double? startLocationLon,
    String? endLocationName,
    double? endLocationLat,
    double? endLocationLon,
    double? distanceKm,
    String? transportType,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tripName: tripName ?? this.tripName,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startLocationName: startLocationName ?? this.startLocationName,
      startLocationLat: startLocationLat ?? this.startLocationLat,
      startLocationLon: startLocationLon ?? this.startLocationLon,
      endLocationName: endLocationName ?? this.endLocationName,
      endLocationLat: endLocationLat ?? this.endLocationLat,
      endLocationLon: endLocationLon ?? this.endLocationLon,
      distanceKm: distanceKm ?? this.distanceKm,
      transportType: transportType ?? this.transportType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 100) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }

  String get formattedDuration {
    final duration = endDate.difference(startDate);
    if (duration.inDays == 0) {
      return 'Same day';
    } else if (duration.inDays == 1) {
      return '1 day';
    } else {
      return '${duration.inDays} days';
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'planned':
        return 'Planned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}
