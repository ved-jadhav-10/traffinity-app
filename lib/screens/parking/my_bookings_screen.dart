import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/parking_service.dart';
import '../../models/parking_booking.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  final ParkingService _parkingService = ParkingService();
  late TabController _tabController;

  List<ParkingBooking> _allBookings = [];
  List<ParkingBooking> _activeBookings = [];
  List<ParkingBooking> _pendingBookings = [];
  List<ParkingBooking> _pastBookings = [];

  bool _isLoading = true;
  StreamSubscription? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    try {
      final bookings = await _parkingService.getUserBookings();
      if (mounted) {
        setState(() {
          _allBookings = bookings;
          _categorizeBookings();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading bookings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bookings: $e'),
            backgroundColor: const Color(0xFFf54248),
          ),
        );
      }
    }
  }

  void _categorizeBookings() {
    _activeBookings = _allBookings.where((b) => b.isActive).toList();
    _pendingBookings = _allBookings.where((b) => b.isPending).toList();
    _pastBookings = _allBookings
        .where((b) =>
            (b.isApproved && b.isExpired) || b.isRejected || b.isCancelled)
        .toList();
  }

  void _subscribeToUpdates() {
    _realtimeSubscription = _parkingService.subscribeToBookingUpdates(
      (bookings) {
        if (mounted) {
          // Check for newly approved bookings
          final newlyApproved = bookings.where((newBooking) {
            final oldBooking = _allBookings.firstWhere(
              (b) => b.id == newBooking.id,
              orElse: () => newBooking,
            );
            return oldBooking.isPending && newBooking.isApproved;
          }).toList();

          // Show notification for each newly approved booking
          for (final booking in newlyApproved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✓ Your booking for ${booking.parkingLayoutName ?? "parking"} - Spot ${booking.slotLabel} has been approved!',
                ),
                backgroundColor: const Color(0xFF06d6a0),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'VIEW',
                  textColor: Colors.white,
                  onPressed: () {
                    _tabController.animateTo(0); // Switch to Active tab
                  },
                ),
              ),
            );
          }

          setState(() {
            _allBookings = bookings;
            _categorizeBookings();
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF2a2a2a),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF3a3a3a)),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1c1c1c),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFFf5f6fa),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'My Bookings',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFf5f6fa),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF2a2a2a),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF3a3a3a)),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF06d6a0),
                labelColor: const Color(0xFF06d6a0),
                unselectedLabelColor: const Color(0xFF9e9e9e),
                labelStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(
                    text: 'Active (${_activeBookings.length})',
                  ),
                  Tab(
                    text: 'Pending (${_pendingBookings.length})',
                  ),
                  Tab(
                    text: 'Past (${_pastBookings.length})',
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF06d6a0),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBookingList(_activeBookings, 'active'),
                        _buildBookingList(_pendingBookings, 'pending'),
                        _buildBookingList(_pastBookings, 'past'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList(List<ParkingBooking> bookings, String type) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'active'
                  ? Icons.event_available
                  : type == 'pending'
                      ? Icons.schedule
                      : Icons.history,
              size: 64,
              color: const Color(0xFF9e9e9e).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type} bookings',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Color(0xFF9e9e9e),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: const Color(0xFF06d6a0),
      backgroundColor: const Color(0xFF2a2a2a),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          return _buildBookingCard(bookings[index]);
        },
      ),
    );
  }

  Widget _buildBookingCard(ParkingBooking booking) {
    Color statusColor = _getStatusColor(booking.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3a3a3a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Parking name + Status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.parkingLayoutName ?? 'Unknown Parking',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFf5f6fa),
                      ),
                    ),
                    if (booking.slotLabel != null)
                      Text(
                        'Spot ${booking.slotLabel}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF9e9e9e),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  booking.displayStatus,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Divider
          Container(
            height: 1,
            color: const Color(0xFF3a3a3a),
          ),
          const SizedBox(height: 12),

          // Booking details
          _buildDetailRow(Icons.calendar_today, 'Date & Time',
              booking.formattedDateRange),
          const SizedBox(height: 8),
          _buildDetailRow(
              Icons.access_time, 'Duration', booking.formattedDuration),
          const SizedBox(height: 8),
          _buildDetailRow(
              Icons.directions_car, 'Vehicle', booking.vehicleNumber),
          const SizedBox(height: 8),
          _buildDetailRow(
              Icons.category, 'Type', booking.vehicleType),
          if (booking.formattedTotalPrice != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(Icons.payment, 'Amount',
                booking.formattedTotalPrice!,
                valueColor: const Color(0xFF06d6a0)),
          ],
          if (booking.parkingLocation != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
                Icons.location_on, 'Location', booking.parkingLocation!),
          ],

          // Active booking countdown
          if (booking.isOngoing) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF06d6a0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF06d6a0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Color(0xFF06d6a0),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active parking session',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF06d6a0),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Upcoming booking info
          if (booking.isUpcoming) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4a90e2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4a90e2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    color: Color(0xFF4a90e2),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Booking starts ${_getTimeUntil(booking.bookingStartTime)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFF4a90e2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9e9e9e)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Color(0xFF9e9e9e),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFFf5f6fa),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFffa726);
      case 'approved':
        return const Color(0xFF06d6a0);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFf54248);
      default:
        return const Color(0xFF9e9e9e);
    }
  }

  String _getTimeUntil(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'soon';
    }
  }
}
