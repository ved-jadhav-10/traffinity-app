import 'package:latlong2/latlong.dart';

class TrafficIncident {
  final String id;
  final String userId;
  final String incidentType; // 'accident', 'roadwork', 'event'
  final String severity; // 'Minor', 'Moderate', 'Severe', 'Critical'
  final double latitude;
  final double longitude;
  final DateTime startTime;
  final int durationMinutes; // 5, 15, 30, 60, 240, or -1 for unknown
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  TrafficIncident({
    required this.id,
    required this.userId,
    required this.incidentType,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.startTime,
    required this.durationMinutes,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  LatLng get location => LatLng(latitude, longitude);

  String get formattedDuration {
    if (durationMinutes == -1) return 'Unknown';
    if (durationMinutes < 60) return '$durationMinutes min';
    final hours = durationMinutes ~/ 60;
    return '$hours hour${hours > 1 ? 's' : ''}';
  }

  DateTime? get estimatedEndTime {
    if (durationMinutes == -1) return null;
    return startTime.add(Duration(minutes: durationMinutes));
  }

  bool get isExpired {
    final now = DateTime.now();
    // Expired after 12 hours from start time
    return now.difference(startTime).inHours >= 12;
  }

  bool get isStillActive {
    if (isExpired) return false;
    if (durationMinutes == -1) return true; // Unknown duration, assume active
    final endTime = estimatedEndTime;
    if (endTime == null) return true;
    return DateTime.now().isBefore(endTime);
  }

  String get iconPath {
    switch (incidentType) {
      case 'accident':
        return 'assets/icons/accident.png';
      case 'roadwork':
        return 'assets/icons/roadwork.png';
      case 'event':
        return 'assets/icons/event.png';
      default:
        return 'assets/icons/accident.png';
    }
  }

  String get displayName {
    switch (incidentType) {
      case 'accident':
        return 'Accident';
      case 'roadwork':
        return 'Road Work';
      case 'event':
        return 'Event';
      default:
        return incidentType;
    }
  }

  factory TrafficIncident.fromJson(Map<String, dynamic> json) {
    return TrafficIncident(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      incidentType: json['incident_type'] as String,
      severity: json['severity'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      startTime: DateTime.parse(json['start_time'] as String),
      durationMinutes: json['duration_minutes'] as int,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'incident_type': incidentType,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
      'start_time': startTime.toIso8601String(),
      'duration_minutes': durationMinutes,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'incident_type': incidentType,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
      'start_time': startTime.toIso8601String(),
      'duration_minutes': durationMinutes,
      'description': description,
    };
  }
}

class TrafficFlowData {
  final double latitude;
  final double longitude;
  final double currentSpeed;
  final double freeFlowSpeed;
  final double confidence;

  TrafficFlowData({
    required this.latitude,
    required this.longitude,
    required this.currentSpeed,
    required this.freeFlowSpeed,
    required this.confidence,
  });

  LatLng get location => LatLng(latitude, longitude);

  // Calculate traffic level based on speed ratio
  String get trafficLevel {
    final ratio = currentSpeed / freeFlowSpeed;
    if (ratio >= 0.8) return 'free'; // Green
    if (ratio >= 0.5) return 'moderate'; // Yellow
    if (ratio >= 0.3) return 'slow'; // Orange
    return 'heavy'; // Red
  }

  factory TrafficFlowData.fromJson(Map<String, dynamic> json) {
    return TrafficFlowData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      currentSpeed: (json['currentSpeed'] as num).toDouble(),
      freeFlowSpeed: (json['freeFlowSpeed'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}
