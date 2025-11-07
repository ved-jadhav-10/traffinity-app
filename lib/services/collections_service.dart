import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/collection_model.dart';
import '../models/collection_location_model.dart';

class CollectionsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get user ID
  String? get userId => _supabase.auth.currentUser?.id;

  // ==================== COLLECTIONS ====================

  // Fetch all collections for the current user
  Future<List<Collection>> fetchCollections() async {
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('collections')
        .select()
        .eq('user_id', userId!)
        .order('date_created', ascending: false);

    return (response as List)
        .map((json) => Collection.fromJson(json))
        .toList();
  }

  // Create a new collection
  Future<Collection> createCollection({
    required String collectionName,
    String? collectionDescription,
    String? collectionPicture,
  }) async {
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase.from('collections').insert({
      'user_id': userId,
      'collection_name': collectionName,
      'collection_description': collectionDescription,
      'collection_picture': collectionPicture,
    }).select().single();

    return Collection.fromJson(response);
  }

  // Update a collection
  Future<void> updateCollection({
    required String collectionId,
    required String collectionName,
    String? collectionDescription,
    String? collectionPicture,
  }) async {
    if (userId == null) throw Exception('User not authenticated');

    await _supabase.from('collections').update({
      'collection_name': collectionName,
      'collection_description': collectionDescription,
      'collection_picture': collectionPicture,
    }).eq('id', collectionId).eq('user_id', userId!);
  }

  // Delete a collection
  Future<void> deleteCollection(String collectionId) async {
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('collections')
        .delete()
        .eq('id', collectionId)
        .eq('user_id', userId!);
  }

  // Get collection by ID
  Future<Collection?> getCollectionById(String collectionId) async {
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('collections')
        .select()
        .eq('id', collectionId)
        .eq('user_id', userId!)
        .single();

    return Collection.fromJson(response);
  }

  // ==================== LOCATIONS ====================

  // Fetch all locations for a specific collection
  Future<List<CollectionLocation>> fetchLocationsInCollection(
      String collectionId) async {
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('collection_locations')
        .select()
        .eq('collection_id', collectionId)
        .eq('user_id', userId!)
        .order('date_added', ascending: false);

    return (response as List)
        .map((json) => CollectionLocation.fromJson(json))
        .toList();
  }

  // Get location count for a collection
  Future<int> getLocationCount(String collectionId) async {
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('collection_locations')
        .select('id')
        .eq('collection_id', collectionId)
        .eq('user_id', userId!);

    return (response as List).length;
  }

  // Add a location to a collection
  Future<CollectionLocation> addLocation({
    required String collectionId,
    required String memoryName,
    String? memoryDescription,
    String? picture,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase.from('collection_locations').insert({
      'collection_id': collectionId,
      'user_id': userId,
      'memory_name': memoryName,
      'memory_description': memoryDescription,
      'picture': picture,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    }).select().single();

    return CollectionLocation.fromJson(response);
  }

  // Update a location
  Future<void> updateLocation({
    required String locationId,
    required String memoryName,
    String? memoryDescription,
    String? picture,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    if (userId == null) throw Exception('User not authenticated');

    await _supabase.from('collection_locations').update({
      'memory_name': memoryName,
      'memory_description': memoryDescription,
      'picture': picture,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    }).eq('id', locationId).eq('user_id', userId!);
  }

  // Delete a location
  Future<void> deleteLocation(String locationId) async {
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('collection_locations')
        .delete()
        .eq('id', locationId)
        .eq('user_id', userId!);
  }

  // Get location by ID
  Future<CollectionLocation?> getLocationById(String locationId) async {
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('collection_locations')
        .select()
        .eq('id', locationId)
        .eq('user_id', userId!)
        .single();

    return CollectionLocation.fromJson(response);
  }

  // ==================== STORAGE (for images) ====================

  // Upload image to Supabase Storage
  Future<String?> uploadImage(String filePath, String fileName) async {
    if (userId == null) throw Exception('User not authenticated');

    try {
      await _supabase.storage
          .from('collection-images')
          .upload('$userId/$fileName', File(filePath));

      final publicUrl = _supabase.storage
          .from('collection-images')
          .getPublicUrl('$userId/$fileName');

      return publicUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Delete image from Supabase Storage
  Future<void> deleteImage(String imageUrl) async {
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final path = uri.pathSegments.last;

      await _supabase.storage
          .from('collection-images')
          .remove(['$userId/$path']);
    } catch (e) {
      print('Error deleting image: $e');
    }
  }
}
