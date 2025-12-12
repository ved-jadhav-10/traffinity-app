import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/parking_service.dart';
import '../../models/parking_layout.dart';
import '../../models/parking_slot.dart';
import 'booking_form_screen.dart';

class ParkingLayoutScreen extends StatefulWidget {
  final ParkingLayout layout;

  const ParkingLayoutScreen({super.key, required this.layout});

  @override
  State<ParkingLayoutScreen> createState() => _ParkingLayoutScreenState();
}

class _ParkingLayoutScreenState extends State<ParkingLayoutScreen> {
  final ParkingService _parkingService = ParkingService();
  List<ParkingSlot> _slots = [];
  List<ParkingSlot> _filteredSlots = [];
  bool _isLoading = true;
  StreamSubscription? _realtimeSubscription;
  String? _selectedVehicleTypeFilter; // null means "All"
  List<String> _availableVehicleTypes = [];

  @override
  void initState() {
    super.initState();
    _loadSlots();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    try {
      final slots = await _parkingService.getParkingSlots(widget.layout.id);
      if (mounted) {
        setState(() {
          _slots = slots;
          _filteredSlots = slots;
          _availableVehicleTypes = slots
              .map((s) => s.vehicleType)
              .toSet()
              .toList()
            ..sort();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading parking slots: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load parking slots: $e'),
            backgroundColor: const Color(0xFFf54248),
          ),
        );
      }
    }
  }

  void _applyFilter(String? vehicleType) {
    setState(() {
      _selectedVehicleTypeFilter = vehicleType;
      if (vehicleType == null) {
        _filteredSlots = _slots;
      } else {
        _filteredSlots = _slots
            .where((slot) => slot.vehicleType == vehicleType)
            .toList();
      }
    });
  }

  void _subscribeToUpdates() {
    _realtimeSubscription = _parkingService.subscribeToSlotUpdates(
      widget.layout.id,
      (slots) {
        if (mounted) {
          setState(() {
            _slots = slots;
            _availableVehicleTypes = slots
                .map((s) => s.vehicleType)
                .toSet()
                .toList()
              ..sort();
            // Reapply filter
            if (_selectedVehicleTypeFilter == null) {
              _filteredSlots = slots;
            } else {
              _filteredSlots = slots
                  .where((slot) => slot.vehicleType == _selectedVehicleTypeFilter)
                  .toList();
            }
          });
        }
      },
    );
  }

  void _onSlotTap(ParkingSlot slot) {
    if (!slot.isBookable) {
      // Show status message
      String message;
      if (slot.isOccupied) {
        message = 'This spot is currently occupied';
      } else if (slot.isReserved) {
        message = 'This spot is reserved (pending approval)';
      } else {
        message = 'This spot is under maintenance';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFffa726),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Navigate to booking form
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingFormScreen(
          layout: widget.layout,
          slot: slot,
        ),
      ),
    ).then((_) {
      // Refresh slots after booking
      _loadSlots();
    });
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.layout.name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFf5f6fa),
                          ),
                        ),
                        Text(
                          widget.layout.location,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF9e9e9e),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Legend
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem('Available', const Color(0xFF06d6a0)),
                  _buildLegendItem('Reserved', const Color(0xFFffa726)),
                  _buildLegendItem('Occupied', const Color(0xFFf54248)),
                ],
              ),
            ),

            // Vehicle Type Filter
            if (_availableVehicleTypes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter by Vehicle Type',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9e9e9e),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', null),
                          const SizedBox(width: 8),
                          ..._availableVehicleTypes.map((type) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildFilterChip(type, type),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Parking slots grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF06d6a0),
                      ),
                    )
                  : _filteredSlots.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_parking_outlined,
                                size: 64,
                                color: const Color(0xFF9e9e9e).withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedVehicleTypeFilter != null
                                    ? 'No $_selectedVehicleTypeFilter slots'
                                    : 'No parking slots available',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: Color(0xFF9e9e9e),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadSlots,
                          color: const Color(0xFF06d6a0),
                          backgroundColor: const Color(0xFF2a2a2a),
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: _filteredSlots.length,
                            itemBuilder: (context, index) {
                              final slot = _filteredSlots[index];
                              return _buildSlotCard(slot);
                            },
                          ),
                        ),
            ),

            // Bottom info bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF2a2a2a),
                border: Border(
                  top: BorderSide(color: Color(0xFF3a3a3a)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCountItem(
                    'Total',
                    _filteredSlots.length,
                    const Color(0xFF9e9e9e),
                  ),
                  _buildCountItem(
                    'Available',
                    _filteredSlots.where((s) => s.isAvailable).length,
                    const Color(0xFF06d6a0),
                  ),
                  _buildCountItem(
                    'Reserved',
                    _filteredSlots.where((s) => s.isReserved).length,
                    const Color(0xFFffa726),
                  ),
                  _buildCountItem(
                    'Occupied',
                    _filteredSlots.where((s) => s.isOccupied).length,
                    const Color(0xFFf54248),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotCard(ParkingSlot slot) {
    Color backgroundColor;
    Color borderColor;
    bool isClickable = slot.isBookable;

    if (slot.isAvailable) {
      backgroundColor = const Color(0xFF06d6a0).withOpacity(0.1);
      borderColor = const Color(0xFF06d6a0);
    } else if (slot.isReserved) {
      backgroundColor = const Color(0xFFffa726).withOpacity(0.1);
      borderColor = const Color(0xFFffa726);
    } else if (slot.isOccupied) {
      backgroundColor = const Color(0xFFf54248).withOpacity(0.1);
      borderColor = const Color(0xFFf54248);
    } else {
      backgroundColor = const Color(0xFF3a3a3a).withOpacity(0.1);
      borderColor = const Color(0xFF9e9e9e);
    }

    return GestureDetector(
      onTap: () => _onSlotTap(slot),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Slot label
            Text(
              slot.slotLabel,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isClickable ? borderColor : const Color(0xFF9e9e9e),
              ),
            ),
            const SizedBox(height: 4),
            // Vehicle type - now more prominent
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                slot.vehicleType,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isClickable ? const Color(0xFFf5f6fa) : const Color(0xFF9e9e9e),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            // Status icon
            Icon(
              slot.isAvailable
                  ? Icons.check_circle
                  : slot.isReserved
                      ? Icons.schedule
                      : slot.isOccupied
                          ? Icons.cancel
                          : Icons.build_circle,
              color: borderColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? filterValue) {
    final isSelected = _selectedVehicleTypeFilter == filterValue;
    return GestureDetector(
      onTap: () => _applyFilter(filterValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF06d6a0)
              : const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF06d6a0)
                : const Color(0xFF3a3a3a),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : const Color(0xFFf5f6fa),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Color(0xFF9e9e9e),
          ),
        ),
      ],
    );
  }

  Widget _buildCountItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Color(0xFF9e9e9e),
          ),
        ),
      ],
    );
  }
}
