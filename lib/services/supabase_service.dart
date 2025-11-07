import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
}
