import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/parking_layout.dart';
import '../models/parking_slot.dart';
import '../models/vehicle_type.dart';
import '../models/parking_booking.dart';

class ParkingService {
  static final ParkingService _instance = ParkingService._internal();
  factory ParkingService() => _instance;
  ParkingService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Real-time subscription channels
  RealtimeChannel? _parkingSlotsChannel;
  RealtimeChannel? _bookingsChannel;

  // ============================================
  // Parking Layouts Methods
  // ============================================

  /// Fetch all parking layouts with coordinates
  Future<List<ParkingLayout>> getAllParkingLayouts() async {
    try {
      final response = await _supabase
          .from('parking_layouts')
          .select()
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .order('name');

      return (response as List)
          .map((json) => ParkingLayout.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching parking layouts: $e');
      rethrow;
    }
  }

  /// Get parking layout by ID
  Future<ParkingLayout?> getParkingLayoutById(String layoutId) async {
    try {
      final response = await _supabase
          .from('parking_layouts')
          .select()
          .eq('id', layoutId)
          .maybeSingle();

      if (response == null) return null;
      return ParkingLayout.fromJson(response);
    } catch (e) {
      print('Error fetching parking layout: $e');
      rethrow;
    }
  }

  // ============================================
  // Parking Slots Methods
  // ============================================

  /// Get all parking slots for a specific layout with vehicle type info
  Future<List<ParkingSlot>> getParkingSlots(String layoutId) async {
    try {
      final slotsResponse = await _supabase
          .from('parking_slots')
          .select()
          .eq('layout_id', layoutId)
          .order('slot_label');
      
      final slotsData = slotsResponse as List;

      return slotsData
          .map((json) => ParkingSlot.fromJson(json))
          .where((slot) => slot.hasVehicleType)
          .toList();
    } catch (e) {
      print('Error fetching parking slots: $e');
      rethrow;
    }
  }

  /// Get available slot count for a parking layout
  Future<int> getAvailableSlotCount(String layoutId) async {
    try {
      final response = await _supabase
          .from('parking_slots')
          .select('id')
          .eq('layout_id', layoutId)
          .eq('status', 'available')
          .count();

      return response.count;
    } catch (e) {
      print('Error counting available slots: $e');
      return 0;
    }
  }

  /// Get slot counts by status for a parking layout
  Future<Map<String, int>> getSlotCountsByStatus(String layoutId) async {
    try {
      final response = await _supabase
          .from('parking_slots')
          .select('status')
          .eq('layout_id', layoutId);

      final counts = <String, int>{
        'available': 0,
        'reserved': 0,
        'occupied': 0,
        'maintenance': 0,
      };

      for (final slot in response as List) {
        final status = slot['status'] as String;
        counts[status] = (counts[status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      print('Error fetching slot counts: $e');
      return {};
    }
  }

  // ============================================
  // Vehicle Types Methods
  // ============================================

  /// Get all vehicle types for a parking layout
  Future<List<VehicleType>> getVehicleTypes(String layoutId) async {
    try {
      final response = await _supabase
          .from('vehicle_types')
          .select()
          .eq('parking_layout_id', layoutId)
          .order('name');

      return (response as List)
          .map((json) => VehicleType.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching vehicle types: $e');
      rethrow;
    }
  }

  /// Get vehicle type by ID
  Future<VehicleType?> getVehicleTypeById(String vehicleTypeId) async {
    try {
      final response = await _supabase
          .from('vehicle_types')
          .select()
          .eq('id', vehicleTypeId)
          .maybeSingle();

      if (response == null) return null;
      return VehicleType.fromJson(response);
    } catch (e) {
      print('Error fetching vehicle type: $e');
      rethrow;
    }
  }

  // ============================================
  // Bookings Methods
  // ============================================

  /// Create a new parking booking
  Future<ParkingBooking> createBooking({
    required String slotId,
    required String vehicleNumber,
    required String vehicleType,
    String? vehicleTypeId,
    required int duration,
    required DateTime bookingStartTime,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get user's name from auth
      final user = _supabase.auth.currentUser;
      final userName = user?.userMetadata?['first_name'] != null &&
              user?.userMetadata?['last_name'] != null
          ? '${user!.userMetadata!['first_name']} ${user.userMetadata!['last_name']}'
          : user?.email?.split('@')[0] ?? 'User';

      // Calculate end time
      final bookingEndTime =
          bookingStartTime.add(Duration(hours: duration));

      // Create booking
      final response = await _supabase
          .from('bookings')
          .insert({
            'slot_id': slotId,
            'user_id': userId,
            'user_name': userName,
            'vehicle_number': vehicleNumber,
            'vehicle_type': vehicleType,
            'vehicle_type_id': vehicleTypeId,
            'duration': duration,
            'status': 'pending',
            'booking_start_time': bookingStartTime.toIso8601String(),
            'booking_end_time': bookingEndTime.toIso8601String(),
          })
          .select()
          .single();

      return ParkingBooking.fromJson(response);
    } catch (e) {
      print('Error creating booking: $e');
      rethrow;
    }
  }

  /// Get all bookings for current user
  Future<List<ParkingBooking>> getUserBookings() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('bookings')
          .select('''
            *,
            parking_slots!inner(
              slot_label,
              parking_layouts!inner(
                name,
                location
              )
            ),
            vehicle_types(price_per_hour)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        // Extract nested data
        final slot = json['parking_slots'];
        final layout = slot?['parking_layouts'];
        final vehicleTypeData = json['vehicle_types'];

        return ParkingBooking.fromJson({
          ...json,
          'slot_label': slot?['slot_label'],
          'parking_layout_name': layout?['name'],
          'parking_location': layout?['location'],
          'price_per_hour': vehicleTypeData?['price_per_hour'],
        });
      }).toList();
    } catch (e) {
      print('Error fetching user bookings: $e');
      rethrow;
    }
  }

  /// Get active bookings for current user
  Future<List<ParkingBooking>> getActiveBookings() async {
    final bookings = await getUserBookings();
    final now = DateTime.now();
    
    return bookings
        .where((b) =>
            b.isApproved &&
            b.bookingEndTime.isAfter(now))
        .toList();
  }

  /// Get pending bookings for current user
  Future<List<ParkingBooking>> getPendingBookings() async {
    final bookings = await getUserBookings();
    return bookings.where((b) => b.isPending).toList();
  }

  /// Get past bookings for current user
  Future<List<ParkingBooking>> getPastBookings() async {
    final bookings = await getUserBookings();
    final now = DateTime.now();
    
    return bookings
        .where((b) =>
            (b.isApproved && b.bookingEndTime.isBefore(now)) ||
            b.isRejected ||
            b.isCancelled)
        .toList();
  }

  /// Check if a slot is available for booking at a specific time
  Future<bool> isSlotAvailableForBooking({
    required String slotId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      // Check if slot exists and is available
      final slotResponse = await _supabase
          .from('parking_slots')
          .select('status')
          .eq('id', slotId)
          .maybeSingle();

      if (slotResponse == null) return false;
      if (slotResponse['status'] != 'available') return false;

      // Check for overlapping bookings
      final bookingResponse = await _supabase
          .from('bookings')
          .select('id')
          .eq('slot_id', slotId)
          .inFilter('status', ['pending', 'approved'])
          .or('booking_start_time.lte.${endTime.toIso8601String()},booking_end_time.gte.${startTime.toIso8601String()}');

      return (bookingResponse as List).isEmpty;
    } catch (e) {
      print('Error checking slot availability: $e');
      return false;
    }
  }

  /// Cancel a booking (user can cancel pending bookings)
  Future<void> cancelBooking(String bookingId) async {
    try {
      await _supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId);
    } catch (e) {
      print('Error cancelling booking: $e');
      rethrow;
    }
  }

  // ============================================
  // Real-time Subscriptions
  // ============================================

  /// Subscribe to parking slot updates for a specific layout
  StreamSubscription<List<ParkingSlot>> subscribeToSlotUpdates(
    String layoutId,
    Function(List<ParkingSlot>) callback,
  ) {
    // Create a stream controller
    final controller = StreamController<List<ParkingSlot>>();

    // Initial fetch
    getParkingSlots(layoutId).then((slots) {
      controller.add(slots);
      callback(slots);
    });

    // Subscribe to changes
    _parkingSlotsChannel?.unsubscribe();
    _parkingSlotsChannel = _supabase
        .channel('parking_slots_$layoutId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'parking_slots',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'layout_id',
            value: layoutId,
          ),
          callback: (payload) async {
            // Refetch all slots when any change occurs
            final slots = await getParkingSlots(layoutId);
            controller.add(slots);
            callback(slots);
          },
        )
        .subscribe();

    return controller.stream.listen((_) {});
  }

  /// Subscribe to booking updates for current user
  StreamSubscription<List<ParkingBooking>> subscribeToBookingUpdates(
    Function(List<ParkingBooking>) callback,
  ) {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Create a stream controller
    final controller = StreamController<List<ParkingBooking>>();

    // Initial fetch
    getUserBookings().then((bookings) {
      controller.add(bookings);
      callback(bookings);
    });

    // Subscribe to changes
    _bookingsChannel?.unsubscribe();
    _bookingsChannel = _supabase
        .channel('user_bookings_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            // Refetch all bookings when any change occurs
            final bookings = await getUserBookings();
            controller.add(bookings);
            callback(bookings);
          },
        )
        .subscribe();

    return controller.stream.listen((_) {});
  }

  /// Unsubscribe from all real-time channels
  void unsubscribeAll() {
    _parkingSlotsChannel?.unsubscribe();
    _bookingsChannel?.unsubscribe();
  }

  // ============================================
  // Utility Methods
  // ============================================

  /// Get parking layout with availability info
  Future<Map<String, dynamic>> getParkingLayoutWithAvailability(
      String layoutId) async {
    try {
      final layout = await getParkingLayoutById(layoutId);
      if (layout == null) throw Exception('Parking layout not found');

      final slotCounts = await getSlotCountsByStatus(layoutId);
      final vehicleTypes = await getVehicleTypes(layoutId);

      return {
        'layout': layout,
        'total_slots': slotCounts.values.reduce((a, b) => a + b),
        'available_slots': slotCounts['available'] ?? 0,
        'reserved_slots': slotCounts['reserved'] ?? 0,
        'occupied_slots': slotCounts['occupied'] ?? 0,
        'maintenance_slots': slotCounts['maintenance'] ?? 0,
        'vehicle_types': vehicleTypes,
      };
    } catch (e) {
      print('Error fetching parking layout with availability: $e');
      rethrow;
    }
  }

  /// Get booking details with full information
  Future<Map<String, dynamic>?> getBookingDetails(String bookingId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('''
            *,
            parking_slots!inner(
              slot_label,
              parking_layouts!inner(
                name,
                location,
                latitude,
                longitude
              )
            ),
            vehicle_types(name, price)
          ''')
          .eq('id', bookingId)
          .maybeSingle();

      if (response == null) return null;

      final slot = response['parking_slots'];
      final layout = slot?['parking_layouts'];
      final vehicleTypeData = response['vehicle_types'];

      final booking = ParkingBooking.fromJson({
        ...response,
        'slot_label': slot?['slot_label'],
        'parking_layout_name': layout?['name'],
        'parking_location': layout?['location'],
        'price_per_hour': vehicleTypeData?['price'],
      });

      return {
        'booking': booking,
        'parking_name': layout?['name'],
        'parking_location': layout?['location'],
        'parking_coordinates': layout?['latitude'] != null && layout?['longitude'] != null
            ? {'lat': layout!['latitude'], 'lng': layout['longitude']}
            : null,
        'slot_label': slot?['slot_label'],
        'vehicle_type_name': vehicleTypeData?['name'],
      };
    } catch (e) {
      print('Error fetching booking details: $e');
      rethrow;
    }
  }

  /// Dispose method to clean up subscriptions
  void dispose() {
    unsubscribeAll();
  }
}
