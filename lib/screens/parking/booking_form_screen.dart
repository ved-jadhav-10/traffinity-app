import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/parking_service.dart';
import '../../models/parking_layout.dart';
import '../../models/parking_slot.dart';
import '../../models/vehicle_type.dart';

class BookingFormScreen extends StatefulWidget {
  final ParkingLayout layout;
  final ParkingSlot slot;

  const BookingFormScreen({
    super.key,
    required this.layout,
    required this.slot,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final ParkingService _parkingService = ParkingService();
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();

  List<VehicleType> _vehicleTypes = [];
  VehicleType? _selectedVehicleType;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _selectedDuration = 1;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadVehicleTypes();
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleTypes() async {
    try {
      final types = await _parkingService.getVehicleTypes(widget.layout.id);
      if (mounted) {
        setState(() {
          _vehicleTypes = types;
          // Pre-select vehicle type if slot has one assigned
          if (widget.slot.vehicleTypeId != null) {
            _selectedVehicleType = types.firstWhere(
              (t) => t.id == widget.slot.vehicleTypeId,
              orElse: () => types.first,
            );
          } else if (types.isNotEmpty) {
            _selectedVehicleType = types.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading vehicle types: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 7));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: maxDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF06d6a0),
              onPrimary: Colors.white,
              surface: Color(0xFF2a2a2a),
              onSurface: Color(0xFFf5f6fa),
            ),
            dialogBackgroundColor: const Color(0xFF2a2a2a),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF06d6a0),
              onPrimary: Colors.white,
              surface: Color(0xFF2a2a2a),
              onSurface: Color(0xFFf5f6fa),
            ),
            dialogBackgroundColor: const Color(0xFF2a2a2a),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  DateTime get _bookingStartTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  String get _formattedDate {
    return DateFormat('MMM dd, yyyy').format(_selectedDate);
  }

  String get _formattedTime {
    final hour = _selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod;
    final period = _selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  double? get _totalPrice {
    if (_selectedVehicleType != null) {
      return _selectedVehicleType!.calculateTotalPrice(_selectedDuration);
    }
    return null;
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle type'),
          backgroundColor: Color(0xFFf54248),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Check if slot is still available
      final isAvailable = await _parkingService.isSlotAvailableForBooking(
        slotId: widget.slot.id,
        startTime: _bookingStartTime,
        endTime: _bookingStartTime.add(Duration(hours: _selectedDuration)),
      );

      if (!isAvailable) {
        throw Exception('This slot is no longer available for the selected time');
      }

      // Create booking
      await _parkingService.createBooking(
        slotId: widget.slot.id,
        vehicleNumber: _vehicleNumberController.text.trim(),
        vehicleType: _selectedVehicleType!.name,
        vehicleTypeId: _selectedVehicleType!.id,
        duration: _selectedDuration,
        bookingStartTime: _bookingStartTime,
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking submitted! Waiting for admin approval.'),
            backgroundColor: Color(0xFF06d6a0),
            duration: Duration(seconds: 3),
          ),
        );

        // Go back to parking layout screen
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create booking: $e'),
            backgroundColor: const Color(0xFFf54248),
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
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
                  const Expanded(
                    child: Text(
                      'Book Parking Spot',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFf5f6fa),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF06d6a0),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Spot info card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2a2a2a),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF3a3a3a)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF06d6a0).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.local_parking,
                                      color: Color(0xFF06d6a0),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Spot ${widget.slot.slotLabel}',
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFf5f6fa),
                                          ),
                                        ),
                                        Text(
                                          widget.layout.name,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            color: Color(0xFF9e9e9e),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Vehicle Number
                            const Text(
                              'Vehicle Number',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFf5f6fa),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _vehicleNumberController,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Color(0xFFf5f6fa),
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g., MH 01 AB 1234',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF9e9e9e),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF2a2a2a),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF3a3a3a)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF3a3a3a)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF06d6a0)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter vehicle number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Vehicle Type
                            const Text(
                              'Vehicle Type',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFf5f6fa),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2a2a2a),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF3a3a3a)),
                              ),
                              child: DropdownButtonFormField<VehicleType>(
                                value: _selectedVehicleType,
                                dropdownColor: const Color(0xFF2a2a2a),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFFf5f6fa),
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                items: _vehicleTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(type.name),
                                        Text(
                                          type.formattedPrice,
                                          style: const TextStyle(
                                            color: Color(0xFF06d6a0),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedVehicleType = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Date Selection
                            const Text(
                              'Booking Date',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFf5f6fa),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2a2a2a),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF3a3a3a)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          color: Color(0xFF06d6a0),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _formattedDate,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            color: Color(0xFFf5f6fa),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Color(0xFF9e9e9e),
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Time Selection
                            const Text(
                              'Start Time',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFf5f6fa),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _selectTime,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2a2a2a),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF3a3a3a)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          color: Color(0xFF06d6a0),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _formattedTime,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            color: Color(0xFFf5f6fa),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Color(0xFF9e9e9e),
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Duration Selection
                            const Text(
                              'Duration',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFf5f6fa),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2a2a2a),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF3a3a3a)),
                              ),
                              child: DropdownButtonFormField<int>(
                                value: _selectedDuration,
                                dropdownColor: const Color(0xFF2a2a2a),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFFf5f6fa),
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                items: List.generate(24, (index) => index + 1)
                                    .map((hours) {
                                  return DropdownMenuItem(
                                    value: hours,
                                    child: Text('$hours hour${hours > 1 ? 's' : ''}'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedDuration = value;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Price Display
                            if (_totalPrice != null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06d6a0).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF06d6a0)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Amount',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFf5f6fa),
                                      ),
                                    ),
                                    Text(
                                      '₹${_totalPrice!.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF06d6a0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitBooking,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF06d6a0),
                                  disabledBackgroundColor:
                                      const Color(0xFF3a3a3a),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Submit Booking Request',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Info text
                            const Text(
                              'Your booking will be pending until approved by the parking admin. You will receive an email once approved.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0xFF9e9e9e),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
