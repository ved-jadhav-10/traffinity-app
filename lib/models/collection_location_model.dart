class CollectionLocation {
  final String id;
  final String collectionId;
  final String userId;
  final String memoryName;
  final String? memoryDescription;
  final String? picture;
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime dateAdded;

  CollectionLocation({
    required this.id,
    required this.collectionId,
    required this.userId,
    required this.memoryName,
    this.memoryDescription,
    this.picture,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.dateAdded,
  });

  factory CollectionLocation.fromJson(Map<String, dynamic> json) {
    return CollectionLocation(
      id: json['id'],
      collectionId: json['collection_id'],
      userId: json['user_id'],
      memoryName: json['memory_name'],
      memoryDescription: json['memory_description'],
      picture: json['picture'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      dateAdded: DateTime.parse(json['date_added']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection_id': collectionId,
      'user_id': userId,
      'memory_name': memoryName,
      'memory_description': memoryDescription,
      'picture': picture,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'date_added': dateAdded.toIso8601String(),
    };
  }
}
