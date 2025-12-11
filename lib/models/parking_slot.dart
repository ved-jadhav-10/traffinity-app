class ParkingSlot {
  final String id;
  final String layoutId;
  final String slotLabel; // e.g., "A-1", "B-10", "C-5"
  final String? vehicleTypeId;
  final String status; // 'available', 'reserved', 'occupied', 'maintenance'
  final DateTime createdAt;

  // Optional: Populated when joined with vehicle_types
  final String? vehicleTypeName;

  ParkingSlot({
    required this.id,
    required this.layoutId,
    required this.slotLabel,
    this.vehicleTypeId,
    required this.status,
    required this.createdAt,
    this.vehicleTypeName,
  });

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
      vehicleTypeId: json['vehicle_type_id'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      vehicleTypeName: json['vehicle_type_name'] as String?, // From joined query
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'layout_id': layoutId,
      'slot_label': slotLabel,
      'vehicle_type_id': vehicleTypeId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      if (vehicleTypeName != null) 'vehicle_type_name': vehicleTypeName,
    };
  }

  // Copy with method
  ParkingSlot copyWith({
    String? id,
    String? layoutId,
    String? slotLabel,
    String? vehicleTypeId,
    String? status,
    DateTime? createdAt,
    String? vehicleTypeName,
  }) {
    return ParkingSlot(
      id: id ?? this.id,
      layoutId: layoutId ?? this.layoutId,
      slotLabel: slotLabel ?? this.slotLabel,
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      vehicleTypeName: vehicleTypeName ?? this.vehicleTypeName,
    );
  }

  @override
  String toString() {
    return 'ParkingSlot(id: $id, label: $slotLabel, status: $status, vehicleType: ${vehicleTypeName ?? "N/A"})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParkingSlot && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
