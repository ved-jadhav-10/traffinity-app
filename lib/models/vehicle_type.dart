class VehicleType {
  final String id;
  final String layoutId;
  final String name; // e.g., "Car", "2-Wheeler", "Truck"
  final double price; // Price per hour
  final DateTime createdAt;

  VehicleType({
    required this.id,
    required this.layoutId,
    required this.name,
    required this.price,
    required this.createdAt,
  });

  // Format price for display
  String get formattedPrice => '₹${price.toStringAsFixed(0)}/hr';

  // Calculate total price for given duration (hours)
  double calculateTotalPrice(int hours) => price * hours;

  // Format total price for given duration
  String formatTotalPrice(int hours) {
    final total = calculateTotalPrice(hours);
    return '₹${total.toStringAsFixed(0)}';
  }

  // Factory constructor from JSON
  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: json['id'] as String,
      layoutId: json['layout_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'layout_id': layoutId,
      'name': name,
      'price': price,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Copy with method
  VehicleType copyWith({
    String? id,
    String? layoutId,
    String? name,
    double? price,
    DateTime? createdAt,
  }) {
    return VehicleType(
      id: id ?? this.id,
      layoutId: layoutId ?? this.layoutId,
      name: name ?? this.name,
      price: price ?? this.price,
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
