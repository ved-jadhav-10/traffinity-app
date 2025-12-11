class ParkingBooking {
  final String id;
  final String slotId;
  final String userId;
  final String userName;
  final String vehicleNumber;
  final String vehicleType; // Text field for vehicle type
  final String? vehicleTypeId; // FK to vehicle_types for pricing
  final int duration; // Hours
  final String status; // 'pending', 'approved', 'rejected', 'cancelled'
  final DateTime bookingStartTime;
  final DateTime bookingEndTime;
  final DateTime createdAt;

  // Optional: Populated when joined with other tables
  final String? slotLabel;
  final String? parkingLayoutName;
  final String? parkingLocation;
  final double? pricePerHour;

  ParkingBooking({
    required this.id,
    required this.slotId,
    required this.userId,
    required this.userName,
    required this.vehicleNumber,
    required this.vehicleType,
    this.vehicleTypeId,
    required this.duration,
    required this.status,
    required this.bookingStartTime,
    required this.bookingEndTime,
    required this.createdAt,
    this.slotLabel,
    this.parkingLayoutName,
    this.parkingLocation,
    this.pricePerHour,
  });

  // Status checks
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';

  // Time checks
  bool get isActive => isApproved && !isExpired;
  bool get isExpired => DateTime.now().isAfter(bookingEndTime);
  bool get isUpcoming => DateTime.now().isBefore(bookingStartTime);
  bool get isOngoing => isApproved && 
                        DateTime.now().isAfter(bookingStartTime) && 
                        DateTime.now().isBefore(bookingEndTime);

  // Display status
  String get displayStatus {
    if (isCancelled) return 'Cancelled';
    if (isRejected) return 'Rejected';
    if (isPending) return 'Pending Approval';
    if (isExpired) return 'Completed';
    if (isOngoing) return 'Active Now';
    if (isUpcoming) return 'Upcoming';
    return 'Confirmed';
  }

  // Status badge color
  String get statusBadgeColor {
    if (isCancelled || isRejected) return '#f54248'; // Red
    if (isPending) return '#ffa726'; // Orange
    if (isActive) return '#06d6a0'; // Green
    if (isExpired) return '#9e9e9e'; // Gray
    return '#4a90e2'; // Blue
  }

  // Calculate total price if pricePerHour is available
  double? get totalPrice {
    if (pricePerHour != null) {
      return pricePerHour! * duration;
    }
    return null;
  }

  String? get formattedTotalPrice {
    final price = totalPrice;
    if (price != null) {
      return '₹${price.toStringAsFixed(0)}';
    }
    return null;
  }

  // Formatted duration
  String get formattedDuration {
    if (duration == 1) return '1 hour';
    return '$duration hours';
  }

  // Format date range
  String get formattedDateRange {
    final startDate = bookingStartTime.day == bookingEndTime.day
        ? _formatTime(bookingStartTime)
        : _formatDateTime(bookingStartTime);
    final endTime = _formatTime(bookingEndTime);
    return '$startDate - $endTime';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${_formatTime(dt)}';
  }

  // Factory constructor from JSON
  factory ParkingBooking.fromJson(Map<String, dynamic> json) {
    return ParkingBooking(
      id: json['id'] as String,
      slotId: json['slot_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      vehicleNumber: json['vehicle_number'] as String,
      vehicleType: json['vehicle_type'] as String,
      vehicleTypeId: json['vehicle_type_id'] as String?,
      duration: json['duration'] as int,
      status: json['status'] as String,
      bookingStartTime: DateTime.parse(json['booking_start_time'] as String),
      bookingEndTime: DateTime.parse(json['booking_end_time'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      slotLabel: json['slot_label'] as String?,
      parkingLayoutName: json['parking_layout_name'] as String?,
      parkingLocation: json['parking_location'] as String?,
      pricePerHour: json['price_per_hour'] != null 
          ? (json['price_per_hour'] as num).toDouble() 
          : null,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slot_id': slotId,
      'user_id': userId,
      'user_name': userName,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'vehicle_type_id': vehicleTypeId,
      'duration': duration,
      'status': status,
      'booking_start_time': bookingStartTime.toIso8601String(),
      'booking_end_time': bookingEndTime.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (slotLabel != null) 'slot_label': slotLabel,
      if (parkingLayoutName != null) 'parking_layout_name': parkingLayoutName,
      if (parkingLocation != null) 'parking_location': parkingLocation,
      if (pricePerHour != null) 'price_per_hour': pricePerHour,
    };
  }

  // Copy with method
  ParkingBooking copyWith({
    String? id,
    String? slotId,
    String? userId,
    String? userName,
    String? vehicleNumber,
    String? vehicleType,
    String? vehicleTypeId,
    int? duration,
    String? status,
    DateTime? bookingStartTime,
    DateTime? bookingEndTime,
    DateTime? createdAt,
    String? slotLabel,
    String? parkingLayoutName,
    String? parkingLocation,
    double? pricePerHour,
  }) {
    return ParkingBooking(
      id: id ?? this.id,
      slotId: slotId ?? this.slotId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      bookingStartTime: bookingStartTime ?? this.bookingStartTime,
      bookingEndTime: bookingEndTime ?? this.bookingEndTime,
      createdAt: createdAt ?? this.createdAt,
      slotLabel: slotLabel ?? this.slotLabel,
      parkingLayoutName: parkingLayoutName ?? this.parkingLayoutName,
      parkingLocation: parkingLocation ?? this.parkingLocation,
      pricePerHour: pricePerHour ?? this.pricePerHour,
    );
  }

  @override
  String toString() {
    return 'ParkingBooking(id: $id, slot: ${slotLabel ?? slotId}, status: $status, duration: $formattedDuration)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParkingBooking && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
