import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static SupabaseClient get client => Supabase.instance.client;

  // Initialize Supabase
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  // Check if user is authenticated
  bool get isAuthenticated => client.auth.currentUser != null;

  // Get current user
  User? get currentUser => client.auth.currentUser;

  // Check if user exists by email
  Future<bool> checkUserExists(String email) async {
    try {
      // Try to get user by email from auth.users (admin only)
      // Since we can't access admin API, we'll try sign in and catch the error
      // This is a workaround - a better approach would be to have a backend endpoint

      // For now, we'll return true and let the sign-in handle the error
      // But we can query the profiles table if you have one
      final response = await client
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      return response != null;
    } catch (e) {
      // If profiles table doesn't exist or error occurs, we can't verify
      // So we'll rely on sign-in error handling
      return true; // Assume exists to avoid blocking
    }
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
      },
    );
    return response;
  }

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      const webClientId =
          '342707697143-unc0kka4569obatram6rdljrm6660rhv.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        serverClientId: webClientId,
      );

      // Sign out first to force account picker
      await googleSignIn.signOut();

      print('Starting Google Sign In...');
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print('Google Sign In cancelled by user');
        return false;
      }

      print('Google user signed in: ${googleUser.email}');
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'No Access Token or ID Token found.';
      }

      print('Signing in to Supabase with Google credentials...');
      await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      print('Successfully signed in to Supabase');
      return true;
    } catch (e) {
      print('Google Sign In Error: $e');
      return false;
    }
  }

  // Sign in with phone (send OTP)
  Future<void> signInWithPhone(String phoneNumber) async {
    await client.auth.signInWithOtp(phone: phoneNumber);
  }

  // Verify OTP
  Future<AuthResponse> verifyOTP({
    required String phone,
    required String token,
  }) async {
    final response = await client.auth.verifyOTP(
      type: OtpType.sms,
      phone: phone,
      token: token,
    );
    return response;
  }

  // Verify email OTP
  Future<AuthResponse> verifyEmailOTP({
    required String email,
    required String token,
  }) async {
    final response = await client.auth.verifyOTP(
      type: OtpType.email,
      email: email,
      token: token,
    );
    return response;
  }

  // Resend OTP
  Future<void> resendOTP({String? email, String? phone}) async {
    if (email != null) {
      await client.auth.resend(type: OtpType.signup, email: email);
    } else if (phone != null) {
      await client.auth.resend(type: OtpType.sms, phone: phone);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Listen to auth state changes
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // Get user's first name
  Future<String> getUserFirstName() async {
    try {
      final user = currentUser;
      if (user == null) return 'User';

      // First, try to fetch from profiles table
      final response = await client
          .from('profiles')
          .select('first_name')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && response['first_name'] != null) {
        return response['first_name'] as String;
      }

      // Fallback to user metadata
      final metadata = user.userMetadata;
      if (metadata != null && metadata['first_name'] != null) {
        return metadata['first_name'] as String;
      }

      return 'User';
    } catch (e) {
      print('Error getting user first name: $e');
      return 'User';
    }
  }

  // =============== FAVORITE LOCATIONS ===============

  // Add favorite location
  Future<bool> addFavoriteLocation({
    required String name,
    required double latitude,
    required double longitude,
    String? address,
    String? category,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw 'User not authenticated';

      await client.from('favorite_locations').insert({
        'user_id': user.id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'category': category,
      });

      return true;
    } catch (e) {
      print('Error adding favorite location: $e');
      return false;
    }
  }

  // Get all favorite locations for current user
  Future<List<Map<String, dynamic>>> getFavoriteLocations() async {
    try {
      final user = currentUser;
      if (user == null) return [];

      final response = await client
          .from('favorite_locations')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting favorite locations: $e');
      return [];
    }
  }

  // Remove favorite location
  Future<bool> removeFavoriteLocation(String id) async {
    try {
      await client.from('favorite_locations').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error removing favorite location: $e');
      return false;
    }
  }

  // Remove favorite location by coordinates
  Future<bool> removeFavoriteLocationByCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      await client
          .from('favorite_locations')
          .delete()
          .eq('user_id', user.id)
          .eq('latitude', latitude)
          .eq('longitude', longitude);

      return true;
    } catch (e) {
      print('Error removing favorite location by coordinates: $e');
      return false;
    }
  }

  // Check if location is favorited
  Future<bool> isLocationFavorited({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final response = await client
          .from('favorite_locations')
          .select('id')
          .eq('user_id', user.id)
          .eq('latitude', latitude)
          .eq('longitude', longitude)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking if location is favorited: $e');
      return false;
    }
  }

  // =============== RECENT SEARCHES ===============

  // Add recent search
  Future<bool> addRecentSearch({
    required String query,
    required String name,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw 'User not authenticated';

      // Check if search already exists
      final existing = await client
          .from('recent_searches')
          .select('id')
          .eq('user_id', user.id)
          .eq('query', query)
          .maybeSingle();

      if (existing != null) {
        // Update timestamp if exists
        await client
            .from('recent_searches')
            .update({'created_at': DateTime.now().toIso8601String()})
            .eq('id', existing['id']);
      } else {
        // Insert new search
        await client.from('recent_searches').insert({
          'user_id': user.id,
          'query': query,
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        });
      }

      return true;
    } catch (e) {
      print('Error adding recent search: $e');
      return false;
    }
  }

  // Get recent searches for current user
  Future<List<Map<String, dynamic>>> getRecentSearches({int limit = 10}) async {
    try {
      final user = currentUser;
      if (user == null) return [];

      final response = await client
          .from('recent_searches')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting recent searches: $e');
      return [];
    }
  }

  // Clear recent searches
  Future<bool> clearRecentSearches() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      await client.from('recent_searches').delete().eq('user_id', user.id);
      return true;
    } catch (e) {
      print('Error clearing recent searches: $e');
      return false;
    }
  }

  // =============== USER PROFILE ===============

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final user = currentUser;
      if (user == null) throw 'User not authenticated';

      // Get profile from user_profiles table
      final response = await client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // Get name from user metadata
      final metadata = user.userMetadata;
      final firstName = metadata?['first_name'] ?? '';
      final lastName = metadata?['last_name'] ?? '';
      final name = '$firstName $lastName'.trim();

      if (response != null) {
        return {
          'name': name.isEmpty ? 'User' : name,
          'email': user.email ?? '',
          'phone_number': response['phone_number'] ?? '',
          'vehicles': response['vehicles'] ?? [],
        };
      } else {
        // Create profile if doesn't exist
        await client.from('user_profiles').insert({'id': user.id});
        
        return {
          'name': name.isEmpty ? 'User' : name,
          'email': user.email ?? '',
          'phone_number': '',
          'vehicles': [],
        };
      }
    } catch (e) {
      print('Error getting user profile: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile({
    String? name,
    String? phoneNumber,
    List<Map<String, dynamic>>? vehicles,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw 'User not authenticated';

      // Update user_profiles table
      final Map<String, dynamic> updates = {};
      
      if (phoneNumber != null) {
        updates['phone_number'] = phoneNumber;
      }
      
      if (vehicles != null) {
        updates['vehicles'] = vehicles;
      }
      
      updates['updated_at'] = DateTime.now().toIso8601String();

      await client
          .from('user_profiles')
          .update(updates)
          .eq('id', user.id);

      // Update name in user metadata if provided
      if (name != null && name.isNotEmpty) {
        final nameParts = name.trim().split(' ');
        final firstName = nameParts.first;
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        
        await client.auth.updateUser(
          UserAttributes(
            data: {
              'first_name': firstName,
              'last_name': lastName,
            },
          ),
        );
      }

      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Update password
  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        throw 'User not authenticated';
      }

      // Verify current password by attempting to sign in
      try {
        await client.auth.signInWithPassword(
          email: user.email!,
          password: currentPassword,
        );
      } catch (e) {
        throw 'Current password is incorrect';
      }

      // Update to new password
      await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      return true;
    } catch (e) {
      print('Error updating password: $e');
      rethrow;
    }
  }

  // ==================== Traffic Incidents ====================

  // Report a new traffic incident
  Future<Map<String, dynamic>?> reportTrafficIncident({
    required String incidentType,
    required String severity,
    required double latitude,
    required double longitude,
    required int durationMinutes,
    String? description,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Please sign in to report incidents');
      }

      final incident = {
        'user_id': user.id,
        'incident_type': incidentType,
        'severity': severity,
        'latitude': latitude,
        'longitude': longitude,
        'duration_minutes': durationMinutes,
        'description': description,
      };

      final response = await client
          .from('traffic_incidents')
          .insert(incident)
          .select()
          .single();

      return response;
    } catch (e) {
      print('Error reporting traffic incident: $e');
      rethrow;
    }
  }

  // Get incidents within a radius (in meters) from a location
  Future<List<Map<String, dynamic>>> getIncidentsWithinRadius({
    required double latitude,
    required double longitude,
    int radiusMeters = 20000, // 20km default
  }) async {
    try {
      // Call the PostgreSQL function we created
      final response = await client
          .rpc('get_incidents_within_radius', params: {
        'lat': latitude,
        'lng': longitude,
        'radius_meters': radiusMeters,
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching incidents: $e');
      // Fallback: Get all recent incidents and filter client-side
      try {
        final twelveHoursAgo = DateTime.now()
            .subtract(const Duration(hours: 12))
            .toIso8601String();

        final response = await client
            .from('traffic_incidents')
            .select()
            .gte('start_time', twelveHoursAgo)
            .order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        print('Error fetching incidents (fallback): $e');
        return [];
      }
    }
  }

  // Update an incident
  Future<bool> updateTrafficIncident({
    required String incidentId,
    String? severity,
    int? durationMinutes,
    String? description,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw 'User not authenticated';

      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (severity != null) updates['severity'] = severity;
      if (durationMinutes != null) updates['duration_minutes'] = durationMinutes;
      if (description != null) updates['description'] = description;

      await client
          .from('traffic_incidents')
          .update(updates)
          .eq('id', incidentId)
          .eq('user_id', user.id); // Ensure user owns the incident

      return true;
    } catch (e) {
      print('Error updating traffic incident: $e');
      return false;
    }
  }

  // Delete an incident
  Future<bool> deleteTrafficIncident(String incidentId) async {
    try {
      final user = currentUser;
      if (user == null) throw 'User not authenticated';

      await client
          .from('traffic_incidents')
          .delete()
          .eq('id', incidentId)
          .eq('user_id', user.id); // Ensure user owns the incident

      return true;
    } catch (e) {
      print('Error deleting traffic incident: $e');
      return false;
    }
  }

  // Clean up expired incidents (call this periodically from the app)
  Future<void> cleanupExpiredIncidents() async {
    try {
      await client.rpc('delete_expired_incidents');
    } catch (e) {
      print('Error cleaning up expired incidents: $e');
    }
  }

  // ==================== TRIPS METHODS ====================

  // Get all trips for current user
  Future<List<Map<String, dynamic>>> getUserTrips() async {
    try {
      final response = await client
          .from('user_trips')
          .select()
          .eq('user_id', currentUser!.id)
          .order('start_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching trips: $e');
      return [];
    }
  }

  // Add a new trip
  Future<Map<String, dynamic>?> addTrip({
    required String tripName,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required String startLocationName,
    required double startLocationLat,
    required double startLocationLon,
    required String endLocationName,
    required double endLocationLat,
    required double endLocationLon,
    required double distanceKm,
    required String transportType,
    required String status,
  }) async {
    try {
      final response = await client.from('user_trips').insert({
        'user_id': currentUser!.id,
        'trip_name': tripName,
        'description': description,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'start_location_name': startLocationName,
        'start_location_lat': startLocationLat,
        'start_location_lon': startLocationLon,
        'end_location_name': endLocationName,
        'end_location_lat': endLocationLat,
        'end_location_lon': endLocationLon,
        'distance_km': distanceKm,
        'transport_type': transportType,
        'status': status,
      }).select().single();

      return response;
    } catch (e) {
      print('Error adding trip: $e');
      return null;
    }
  }

  // Update a trip
  Future<bool> updateTrip({
    required String tripId,
    required String tripName,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required String startLocationName,
    required double startLocationLat,
    required double startLocationLon,
    required String endLocationName,
    required double endLocationLat,
    required double endLocationLon,
    required double distanceKm,
    required String transportType,
    required String status,
  }) async {
    try {
      await client.from('user_trips').update({
        'trip_name': tripName,
        'description': description,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'start_location_name': startLocationName,
        'start_location_lat': startLocationLat,
        'start_location_lon': startLocationLon,
        'end_location_name': endLocationName,
        'end_location_lat': endLocationLat,
        'end_location_lon': endLocationLon,
        'distance_km': distanceKm,
        'transport_type': transportType,
        'status': status,
      }).eq('id', tripId).eq('user_id', currentUser!.id);

      return true;
    } catch (e) {
      print('Error updating trip: $e');
      return false;
    }
  }

  // Delete a trip
  Future<bool> deleteTrip(String tripId) async {
    try {
      await client
          .from('user_trips')
          .delete()
          .eq('id', tripId)
          .eq('user_id', currentUser!.id);

      return true;
    } catch (e) {
      print('Error deleting trip: $e');
      return false;
    }
  }

  // ==================== CIVIC ISSUES ====================

  // Report a new civic issue (anonymous)
  Future<Map<String, dynamic>?> reportCivicIssue({
    required String issueType,
    required double latitude,
    required double longitude,
    String? description,
    String? photoUrl,
  }) async {
    try {
      final issue = {
        'issue_type': issueType,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'photo_url': photoUrl,
      };

      final response = await client
          .from('civic_issues')
          .insert(issue)
          .select()
          .single();

      return response;
    } catch (e) {
      print('Error reporting civic issue: $e');
      rethrow;
    }
  }

  // Get civic issues within a radius (in meters) from a location
  Future<List<Map<String, dynamic>>> getCivicIssuesWithinRadius({
    required double latitude,
    required double longitude,
    int radiusMeters = 20000, // 20km default
  }) async {
    try {
      // Call the PostgreSQL function we created
      final response = await client
          .rpc('get_civic_issues_within_radius', params: {
        'lat': latitude,
        'lng': longitude,
        'radius_meters': radiusMeters,
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching civic issues: $e');
      // Fallback: Get all issues and filter client-side
      try {
        final response = await client
            .from('civic_issues')
            .select()
            .order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        print('Error fetching civic issues (fallback): $e');
        return [];
      }
    }
  }

  // Upload civic issue photo to Supabase Storage (anonymous)
  Future<String?> uploadCivicIssuePhoto(String filePath) async {
    try {
      print('📸 Starting photo upload...');
      print('File path: $filePath');
      
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ Error: File does not exist at path: $filePath');
        throw Exception('Photo file not found');
      }
      
      print('✅ File exists, size: ${await file.length()} bytes');

      // Generate unique filename with timestamp
      final fileName = 'civic_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = fileName; // Upload to root of bucket, not subfolder
      
      print('Uploading to: $path');

      // Upload to Supabase Storage with upsert option
      await client.storage.from('civic-photos').upload(
        path,
        file,
        fileOptions: const FileOptions(
          upsert: true,
        ),
      );
      
      print('✅ Upload successful!');

      // Get public URL
      final publicUrl = client.storage.from('civic-photos').getPublicUrl(path);
      
      print('📷 Public URL: $publicUrl');

      return publicUrl;
    } catch (e) {
      print('❌ Error uploading civic issue photo: $e');
      rethrow; // Rethrow to show user the actual error
    }
  }
}
