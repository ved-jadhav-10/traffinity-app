class VehicleType {
  final String id;
  final String parkingLayoutId;
  final String name; // e.g., "Car", "2-Wheeler", "Truck"
  final double pricePerHour; // Price per hour
  final DateTime createdAt;

  VehicleType({
    required this.id,
    required this.parkingLayoutId,
    required this.name,
    required this.pricePerHour,
    required this.createdAt,
  });

  // Format price for display
  String get formattedPrice => '₹${pricePerHour.toStringAsFixed(0)}/hr';

  // Calculate total price for given duration (hours)
  double calculateTotalPrice(int hours) => pricePerHour * hours;

  // Format total price for given duration
  String formatTotalPrice(int hours) {
    final total = calculateTotalPrice(hours);
    return '₹${total.toStringAsFixed(0)}';
  }

  // Factory constructor from JSON
  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: json['id'] as String,
      parkingLayoutId: json['parking_layout_id'] as String,
      name: json['name'] as String,
      pricePerHour: (json['price_per_hour'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parking_layout_id': parkingLayoutId,
      'name': name,
      'price_per_hour': pricePerHour,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Copy with method
  VehicleType copyWith({
    String? id,
    String? parkingLayoutId,
    String? name,
    double? pricePerHour,
    DateTime? createdAt,
  }) {
    return VehicleType(
      id: id ?? this.id,
      parkingLayoutId: parkingLayoutId ?? this.parkingLayoutId,
      name: name ?? this.name,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'VehicleType(id: $id, name: $name, price: $formattedPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VehicleType && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
