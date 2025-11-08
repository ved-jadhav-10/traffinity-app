class CivicIssue {
  final String id;
  final String issueType;
  final double latitude;
  final double longitude;
  final String? description;
  final String? photoUrl;
  final DateTime createdAt;
  final double? distanceMeters;

  CivicIssue({
    required this.id,
    required this.issueType,
    required this.latitude,
    required this.longitude,
    this.description,
    this.photoUrl,
    required this.createdAt,
    this.distanceMeters,
  });

  factory CivicIssue.fromJson(Map<String, dynamic> json) {
    return CivicIssue(
      id: json['id'] as String,
      issueType: json['issue_type'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      distanceMeters: json['distance_meters'] != null
          ? (json['distance_meters'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_type': issueType,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
      if (distanceMeters != null) 'distance_meters': distanceMeters,
    };
  }

  // Helper method to get display name for issue type
  String get issueTypeDisplay {
    switch (issueType) {
      case 'water_shortage':
        return 'Water Wastage/Lack of Water';
      case 'garbage_disposal':
        return 'Bad Garbage Disposal';
      case 'air_pollution':
        return 'Air Pollution';
      case 'drainage_issue':
        return 'Open Drainage/Not Working Drainage';
      case 'road_damage':
        return 'Road Damage/Potholes';
      default:
        return issueType;
    }
  }

  // Helper method to get icon asset path for issue type
  String get iconAsset {
    switch (issueType) {
      case 'water_shortage':
        return 'assets/images/water.png';
      case 'garbage_disposal':
        return 'assets/images/garbage.png';
      case 'air_pollution':
        return 'assets/images/air_pollution.png';
      case 'drainage_issue':
        return 'assets/images/drainage.png';
      case 'road_damage':
        return 'assets/images/pothole.png';
      default:
        return 'assets/images/logo.png';
    }
  }

  // Helper method to format distance
  String get formattedDistance {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.toStringAsFixed(0)}m away';
    } else {
      return '${(distanceMeters! / 1000).toStringAsFixed(1)}km away';
    }
  }

  // Helper method to get time ago
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
