import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../services/parking_service.dart';
import '../../services/location_service.dart';
import '../../models/parking_layout.dart';
import '../../config/tomtom_config.dart';
import 'parking_layout_screen.dart';

class ParkHubMapScreen extends StatefulWidget {
  const ParkHubMapScreen({super.key});

  @override
  State<ParkHubMapScreen> createState() => _ParkHubMapScreenState();
}

class _ParkHubMapScreenState extends State<ParkHubMapScreen> {
  final MapController _mapController = MapController();
  final ParkingService _parkingService = ParkingService();
  final LocationService _locationService = LocationService();

  LatLng? _currentLocation;
  List<ParkingLayout> _parkingLayouts = [];
  List<Marker> _parkingMarkers = [];
  Map<String, int> _availabilityCache = {}; // layoutId -> available count
  bool _isLoading = true;
  Timer? _refreshTimer;
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _compassHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _startAutoRefresh();
    _setupCompass();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }

  void _setupCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (mounted && event.heading != null) {
        setState(() {
          _compassHeading = event.heading!;
        });
      }
    });
  }

  void _resetMapRotation() {
    _mapController.rotate(0);
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, _mapController.camera.zoom);
    }
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);

    // Get current location
    bool hasPermission = await _locationService.checkAndRequestPermissions();
    if (hasPermission) {
      Position? position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }
    }

    // Load parking layouts
    await _loadParkingLayouts();

    setState(() => _isLoading = false);
  }

  Future<void> _loadParkingLayouts() async {
    try {
      final layouts = await _parkingService.getAllParkingLayouts();

      // Fetch availability for each layout
      for (final layout in layouts) {
        final count = await _parkingService.getAvailableSlotCount(layout.id);
        _availabilityCache[layout.id] = count;
      }

      if (mounted) {
        setState(() {
          _parkingLayouts = layouts;
          _buildParkingMarkers();
        });
      }
    } catch (e) {
      print('Error loading parking layouts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load parking locations: $e'),
            backgroundColor: const Color(0xFFf54248),
          ),
        );
      }
    }
  }

  void _buildParkingMarkers() {
    _parkingMarkers = _parkingLayouts.where((layout) => layout.hasCoordinates).map((layout) {
      final availableCount = _availabilityCache[layout.id] ?? 0;
      final isFull = availableCount == 0;

      return Marker(
        point: layout.coordinates!,
        width: 60,
        height: 60,
        child: GestureDetector(
          onTap: () => _showParkingDetails(layout),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Parking image
              Image.asset(
                'assets/images/parking.png',
                width: 50,
                height: 50,
              ),
              // Availability badge
              if (!isFull)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06d6a0),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        availableCount > 99 ? '99+' : '$availableCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ),
              // Full badge
              if (isFull)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFf54248),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _loadParkingLayouts();
    });
  }

  void _showParkingDetails(ParkingLayout layout) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ParkingDetailSheet(
        layout: layout,
        availableSlots: _availabilityCache[layout.id] ?? 0,
        parkingService: _parkingService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1c1c1c),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFf5f6fa)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ParkHub Manager',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFf5f6fa),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF06d6a0)),
            onPressed: _loadParkingLayouts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF06d6a0)),
            )
          : Stack(
        children: [
          // Map
          if (_currentLocation != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation!,
                initialZoom: 13.0,
                minZoom: 10.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.tomtom.com/map/1/tile/basic/night/'
                      '{z}/{x}/{y}.png?key=${TomTomConfig.apiKey}',
                  userAgentPackageName: 'com.traffinity.app',
                ),
                // User location marker
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 30,
                      height: 30,
                      child: const Icon(
                        Icons.my_location,
                        color: Color(0xFF06d6a0),
                        size: 30,
                      ),
                    ),
                    ..._parkingMarkers,
                  ],
                ),
              ],
            ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: const Color(0xFF1c1c1c),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF06d6a0),
                ),
              ),
            ),

          // Compass button for recentering
          Positioned(
            right: 16,
            bottom: 100,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1c1c1c),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                iconSize: 48,
                onPressed: _resetMapRotation,
                icon: Transform.rotate(
                  angle: -_compassHeading * (math.pi / 180),
                  child: Image.asset(
                    'assets/icons/compass.png',
                    width: 48,
                    height: 48,
                    color: const Color(0xFF06d6a0),
                  ),
                ),
                tooltip: 'Compass - Recenter & Reset North',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Parking Detail Bottom Sheet
class _ParkingDetailSheet extends StatefulWidget {
  final ParkingLayout layout;
  final int availableSlots;
  final ParkingService parkingService;

  const _ParkingDetailSheet({
    required this.layout,
    required this.availableSlots,
    required this.parkingService,
  });

  @override
  State<_ParkingDetailSheet> createState() => _ParkingDetailSheetState();
}

class _ParkingDetailSheetState extends State<_ParkingDetailSheet> {
  bool _isLoading = true;
  Map<String, int>? _slotCounts;
  List<dynamic>? _vehicleTypes;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final data = await widget.parkingService
          .getParkingLayoutWithAvailability(widget.layout.id);

      if (mounted) {
        setState(() {
          _slotCounts = {
            'total': data['total_slots'],
            'available': data['available_slots'],
            'reserved': data['reserved_slots'],
            'occupied': data['occupied_slots'],
          };
          _vehicleTypes = data['vehicle_types'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading parking details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2a2a2a),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF06d6a0),
                  ),
                )
              : SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3a3a3a),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Parking name
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4a90e2).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.local_parking,
                                color: Color(0xFF4a90e2),
                                size: 24,
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
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFf5f6fa),
                                    ),
                                  ),
                                  Text(
                                    widget.layout.location,
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
                        const SizedBox(height: 24),

                        // Availability stats
                        if (_slotCounts != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1c1c1c),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF3a3a3a)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  'Available',
                                  '${_slotCounts!['available']}',
                                  const Color(0xFF06d6a0),
                                ),
                                _buildStatItem(
                                  'Reserved',
                                  '${_slotCounts!['reserved']}',
                                  const Color(0xFFffa726),
                                ),
                                _buildStatItem(
                                  'Occupied',
                                  '${_slotCounts!['occupied']}',
                                  const Color(0xFFf54248),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Vehicle types & prices
                        if (_vehicleTypes != null && _vehicleTypes!.isNotEmpty) ...[
                          const Text(
                            'Vehicle Types & Pricing',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFf5f6fa),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._vehicleTypes!.map((vt) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1c1c1c),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF3a3a3a)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      vt.name,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        color: Color(0xFFf5f6fa),
                                      ),
                                    ),
                                    Text(
                                      vt.formattedPrice,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF06d6a0),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 24),
                        ],

                        // View layout button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: widget.availableSlots > 0
                                ? () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ParkingLayoutScreen(
                                          layout: widget.layout,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF06d6a0),
                              disabledBackgroundColor: const Color(0xFF3a3a3a),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              widget.availableSlots > 0
                                  ? 'View Layout & Book Spot'
                                  : 'No Available Spots',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
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
}
