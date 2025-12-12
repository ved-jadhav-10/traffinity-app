
class ParkingSlot {
  final String id;
  final String layoutId;
  final String slotLabel; // e.g., "A-1", "B-10", "C-5"
  final String vehicleType; // '2-Wheeler', '4-Wheeler', or 'HMV'
  final String status; // 'available', 'reserved', 'occupied', 'maintenance'
  final DateTime createdAt;

  ParkingSlot({
    required this.id,
    required this.layoutId,
    required this.slotLabel,
    required this.vehicleType,
    required this.status,
    required this.createdAt,
  });

  // Check if slot has valid vehicle type assignment
  bool get hasVehicleType => vehicleType.isNotEmpty;

  // Check status
  bool get isAvailable => status == 'available';
  bool get isReserved => status == 'reserved';
  bool get isOccupied => status == 'occupied';
  bool get isUnderMaintenance => status == 'maintenance';

  // Can this slot be booked?
  bool get isBookable => isAvailable;

  // Get display status text
  String get displayStatus {
    switch (status) {
      case 'available':
        return 'Available';
      case 'reserved':
        return 'Reserved';
      case 'occupied':
        return 'Occupied';
      case 'maintenance':
        return 'Maintenance';
      default:
        return status;
    }
  }

  // Get status color
  String get statusColor {
    switch (status) {
      case 'available':
        return '#06d6a0'; // Green
      case 'reserved':
        return '#ffa726'; // Orange/Yellow
      case 'occupied':
        return '#f54248'; // Red
      case 'maintenance':
        return '#9e9e9e'; // Gray
      default:
        return '#9e9e9e';
    }
  }

  // Factory constructor from JSON
  factory ParkingSlot.fromJson(Map<String, dynamic> json) {
    return ParkingSlot(
      id: json['id'] as String,
      layoutId: json['layout_id'] as String,
      slotLabel: json['slot_label'] as String,
      vehicleType: json['vehicle_type'] as String? ?? '4-Wheeler',
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'layout_id': layoutId,
      'slot_label': slotLabel,
      'vehicle_type': vehicleType,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Get vehicle type display with icon
  String getVehicleTypeDisplay() {
    return vehicleType;
  }

  // Get icon for vehicle type
  String getVehicleTypeIcon() {
    final name = vehicleType.toLowerCase();
    if (name.contains('2') || name.contains('two') || name.contains('bike') || name.contains('scooter')) {
      return '🏍️';
    } else if (name.contains('4') || name.contains('four') || name.contains('car') || name.contains('sedan')) {
      return '🚗';
    } else if (name.contains('hmv') || name.contains('heavy') || name.contains('truck') || name.contains('bus')) {
      return '🚚';
    }
    return '🚗';
  }

  // Copy with method
  ParkingSlot copyWith({
    String? id,
    String? layoutId,
    String? slotLabel,
    String? vehicleType,
    String? status,
    DateTime? createdAt,
  }) {
    return ParkingSlot(
      id: id ?? this.id,
      layoutId: layoutId ?? this.layoutId,
      slotLabel: slotLabel ?? this.slotLabel,
      vehicleType: vehicleType ?? this.vehicleType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ParkingSlot(id: $id, label: $slotLabel, status: $status, vehicleType: $vehicleType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParkingSlot && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
