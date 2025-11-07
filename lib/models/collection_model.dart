class Collection {
  final String id;
  final String userId;
  final String collectionName;
  final String? collectionDescription;
  final String? collectionPicture;
  final DateTime dateCreated;

  Collection({
    required this.id,
    required this.userId,
    required this.collectionName,
    this.collectionDescription,
    this.collectionPicture,
    required this.dateCreated,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'],
      userId: json['user_id'],
      collectionName: json['collection_name'],
      collectionDescription: json['collection_description'],
      collectionPicture: json['collection_picture'],
      dateCreated: DateTime.parse(json['date_created']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'collection_name': collectionName,
      'collection_description': collectionDescription,
      'collection_picture': collectionPicture,
      'date_created': dateCreated.toIso8601String(),
    };
  }
}
