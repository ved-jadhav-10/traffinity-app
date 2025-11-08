import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../services/tomtom_service.dart';
import '../models/traffic_incident_model.dart';
import '../config/tomtom_config.dart';

class CityIncidentMapScreen extends StatefulWidget {
  const CityIncidentMapScreen({super.key});

  @override
  State<CityIncidentMapScreen> createState() => _CityIncidentMapScreenState();
}

class _CityIncidentMapScreenState extends State<CityIncidentMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final SupabaseService _supabaseService = SupabaseService();
  final LocationService _locationService = LocationService();
  final TomTomService _tomtomService = TomTomService();

  LatLng? _currentLocation;
  List<TrafficIncident> _incidents = [];
  List<TomTomIncident> _liveIncidents = [];
  List<Marker> _incidentMarkers = [];
  List<Polyline> _trafficPolylines = [];
  List<TrafficFlowSegment> _trafficFlows = [];
  Timer? _refreshTimer;
  Timer? _mapMoveDebounce;
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _compassHeading = 0.0;
  bool _isLoading = true;
  bool _isMapInitialized = false;
  bool _showLiveIncidents = true; // Toggle for live incidents
  bool _showTrafficFlow = true; // Toggle for traffic flow lines

  // Animation for blinking severe accidents
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize blink animation for severe accidents
    _blinkController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _initializeMap();
    _startAutoRefresh();
    _setupCompass();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapMoveDebounce?.cancel();
    _compassSubscription?.cancel();
    _blinkController.dispose();
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
          _isMapInitialized = true;
        });

        // Load incidents and traffic data
        await _loadIncidents();
        await _loadTrafficData();
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadIncidents() async {
    if (_currentLocation == null) return;

    try {
      // Load community-reported incidents from Supabase
      final incidentsData = await _supabaseService.getIncidentsWithinRadius(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        radiusMeters: 25000, // 25km radius
      );

      // Load live TomTom traffic incidents
      List<TomTomIncident> liveIncidents = [];
      if (_showLiveIncidents) {
        // Calculate bounding box (approximately 25km radius)
        const double kmToDegrees = 0.009; // Rough approximation
        final double offset = kmToDegrees * 25;

        liveIncidents = await _tomtomService.getLiveTrafficIncidents(
          minLat: _currentLocation!.latitude - offset,
          minLon: _currentLocation!.longitude - offset,
          maxLat: _currentLocation!.latitude + offset,
          maxLon: _currentLocation!.longitude + offset,
        );
      }

      if (mounted) {
        setState(() {
          _incidents = incidentsData
              .map((json) => TrafficIncident.fromJson(json))
              .where((incident) => incident.isStillActive)
              .toList();
          _liveIncidents = liveIncidents;
          _buildIncidentMarkers();
        });
      }
    } catch (e) {
      print('Error loading incidents: $e');
    }
  }

  void _buildIncidentMarkers() {
    _incidentMarkers = [];

    // Add community-reported incidents (Supabase)
    _incidentMarkers.addAll(
      _incidents.map((incident) {
        // Check if this is a severe accident
        final isSevereAccident =
            incident.incidentType == 'accident' &&
            incident.severity == 'Severe';

        return Marker(
          point: incident.location,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showIncidentDetails(incident),
            child: isSevereAccident
                ? AnimatedBuilder(
                    animation: _blinkAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _blinkAnimation.value,
                        child: Stack(
                          children: [
                            Image.asset(
                              incident.iconPath,
                              width: 40,
                              height: 40,
                            ),
                            // Small badge to indicate community-reported
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06d6a0),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Stack(
                    children: [
                      Image.asset(incident.iconPath, width: 40, height: 40),
                      // Small badge to indicate community-reported
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF06d6a0),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      }).toList(),
    );

    // Add live TomTom incidents
    if (_showLiveIncidents) {
      _incidentMarkers.addAll(
        _liveIncidents.map((incident) {
          // Check if this is a severe accident from TomTom
          // TomTom iconCategory '1' is accident, magnitudeOfDelay 3+ is severe/critical
          final isSevereAccident =
              incident.iconCategory == '1' && incident.magnitudeOfDelay >= 3;

          return Marker(
            point: incident.location,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showLiveIncidentDetails(incident),
              child: isSevereAccident
                  ? AnimatedBuilder(
                      animation: _blinkAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _blinkAnimation.value,
                          child: Stack(
                            children: [
                              Image.asset(
                                incident.iconPath,
                                width: 40,
                                height: 40,
                              ),
                              // Small badge to indicate live TomTom data
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'L',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Stack(
                      children: [
                        Image.asset(incident.iconPath, width: 40, height: 40),
                        // Small badge to indicate live TomTom data
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: const Center(
                              child: Text(
                                'L',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        }).toList(),
      );
    }
  }

  Future<void> _loadTrafficData() async {
    if (_currentLocation == null) return;

    try {
      if (_showTrafficFlow) {
        // Get the current map center (use current location if map not moved)
        final mapCenter = _mapController.camera.center;

        // Calculate bounding box with 20km radius
        const double kmToDegrees = 0.009;
        final double offset = kmToDegrees * 20; // 20km for traffic flow

        final trafficFlows = await _tomtomService.getLiveTrafficFlow(
          minLat: mapCenter.latitude - offset,
          minLon: mapCenter.longitude - offset,
          maxLat: mapCenter.latitude + offset,
          maxLon: mapCenter.longitude + offset,
          zoom: 12,
        );

        if (mounted) {
          setState(() {
            _trafficFlows = trafficFlows;
            _buildTrafficPolylines();
          });
        }
      }
    } catch (e) {
      print('Error loading traffic data: $e');
    }
  }

  void _onMapPositionChanged() {
    // Cancel existing debounce timer
    _mapMoveDebounce?.cancel();

    // Set a new debounce timer - load traffic after user stops moving for 1 second
    _mapMoveDebounce = Timer(const Duration(milliseconds: 1000), () {
      if (mounted && _showTrafficFlow) {
        _loadTrafficData();
      }
    });
  }

  void _buildTrafficPolylines() {
    _trafficPolylines = _trafficFlows.map((flow) {
      return Polyline(
        points: flow.coordinates,
        color: flow.trafficColor,
        strokeWidth: 6.0,
        borderColor: Colors.black.withOpacity(0.3),
        borderStrokeWidth: 1.0,
      );
    }).toList();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadIncidents();
        _loadTrafficData();
        // Clean up expired incidents
        _supabaseService.cleanupExpiredIncidents();
      }
    });
  }

  void _showIncidentDetails(TrafficIncident incident) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2a2a2a),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9e9e9e),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

            // Badge: Community Reported
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF06d6a0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Community Reported',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1c1c1c),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Incident type with icon
            Row(
              children: [
                Image.asset(incident.iconPath, width: 48, height: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.displayName,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFf5f6fa),
                        ),
                      ),
                      Text(
                        'Severity: ${incident.severity}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: _getSeverityColor(incident.severity),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Time information
            _buildInfoRow(
              Icons.access_time,
              'Started',
              _formatDateTime(incident.startTime),
            ),
            const SizedBox(height: 12),

            _buildInfoRow(Icons.timer, 'Duration', incident.formattedDuration),
            const SizedBox(height: 12),

            if (incident.estimatedEndTime != null)
              _buildInfoRow(
                Icons.event,
                'Expected to clear',
                _formatDateTime(incident.estimatedEndTime!),
              ),
            const SizedBox(height: 12),

            // Description if available
            if (incident.description != null &&
                incident.description!.isNotEmpty) ...[
              const Divider(color: Color(0xFF444444)),
              const SizedBox(height: 12),
              const Text(
                'Description',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9e9e9e),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                incident.description!,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Color(0xFFf5f6fa),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06d6a0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1c1c1c),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _showLiveIncidentDetails(TomTomIncident incident) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2a2a2a),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF9e9e9e),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Badge: Live Traffic Data
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.white, size: 8),
                  SizedBox(width: 4),
                  Text(
                    'Live Traffic Data',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Incident type with icon
            Row(
              children: [
                Image.asset(incident.iconPath, width: 48, height: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.displayName,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFf5f6fa),
                        ),
                      ),
                      Text(
                        'Severity: ${incident.severity}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: _getSeverityColor(incident.severity),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Description
            _buildInfoRow(Icons.info_outline, 'Details', incident.description),
            const SizedBox(height: 12),

            // Road numbers if available
            if (incident.roadNumbers.isNotEmpty)
              _buildInfoRow(
                Icons.route,
                'Roads',
                incident.roadNumbers.join(', '),
              ),
            const SizedBox(height: 12),

            // Location info
            if (incident.fromLocation != null && incident.toLocation != null)
              _buildInfoRow(
                Icons.location_on,
                'Location',
                '${incident.fromLocation} → ${incident.toLocation}',
              ),
            const SizedBox(height: 12),

            // Delay info
            if (incident.delayInSeconds != null)
              _buildInfoRow(
                Icons.timer,
                'Delay',
                '${(incident.delayInSeconds! / 60).round()} minutes',
              ),
            const SizedBox(height: 12),

            // Length info
            if (incident.lengthInMeters != null)
              _buildInfoRow(
                Icons.straighten,
                'Length',
                '${(incident.lengthInMeters! / 1000).toStringAsFixed(1)} km',
              ),

            const SizedBox(height: 20),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF06d6a0), size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Color(0xFF9e9e9e),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFf5f6fa),
            ),
          ),
        ),
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Minor':
        return Colors.yellow;
      case 'Moderate':
        return Colors.orange;
      case 'Severe':
        return Colors.red;
      case 'Critical':
        return Colors.red[900]!;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showReportIncidentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportIncidentSheet(
        currentLocation: _currentLocation!,
        onIncidentReported: () {
          _loadIncidents(); // Refresh incidents after reporting
        },
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
          'City Incident Map',
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
            onPressed: () {
              _loadIncidents();
              _loadTrafficData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF06d6a0)),
            )
          : _isMapInitialized && _currentLocation != null
          ? Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation!,
                    initialZoom: 13.0,
                    minZoom: 10.0,
                    maxZoom: 18.0,
                    onPositionChanged: (position, hasGesture) {
                      // Reload traffic data when map is moved
                      if (hasGesture) {
                        _onMapPositionChanged();
                      }
                    },
                    onLongPress: (tapPosition, point) {
                      // Allow reporting incident at tapped location
                      _showReportIncidentAtLocation(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://api.tomtom.com/map/1/tile/basic/night/'
                          '{z}/{x}/{y}.png?key=${TomTomConfig.apiKey}',
                      userAgentPackageName: 'com.example.traffinity',
                    ),
                    // Traffic polylines
                    PolylineLayer(polylines: _trafficPolylines),
                    // Current location marker
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
                      ],
                    ),
                    // Incident markers
                    MarkerLayer(markers: _incidentMarkers),
                  ],
                ),

                // Info card showing incident count
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2a2a2a).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_incidents.length + _liveIncidents.length} total incidents',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFf5f6fa),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_incidents.length} community · ${_liveIncidents.length} live',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Color(0xFF9e9e9e),
                                  ),
                                ),
                              ],
                            ),
                            // Toggle button for live incidents
                            IconButton(
                              icon: Icon(
                                _showLiveIncidents
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: _showLiveIncidents
                                    ? Colors.red
                                    : const Color(0xFF9e9e9e),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showLiveIncidents = !_showLiveIncidents;
                                });
                                _loadIncidents();
                              },
                              tooltip: _showLiveIncidents
                                  ? 'Hide live incidents'
                                  : 'Show live incidents',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildLegendItem(
                              const Color(0xFF06d6a0),
                              'Community',
                            ),
                            _buildLegendItem(Colors.red, 'Live'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Info note for long press
                Positioned(
                  top: 130, // Below the incident count card
                  left: 16,
                  right: 16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a2a2a).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Color(0xFF06d6a0),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Long press on the map to report an incident',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF9e9e9e),
                            ),
                          ),
                        ],
                      ),
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
            )
          : const Center(
              child: Text(
                'Unable to get your location',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Color(0xFF9e9e9e),
                ),
              ),
            ),
      floatingActionButton: _isMapInitialized
          ? FloatingActionButton.extended(
              onPressed: _showReportIncidentSheet,
              backgroundColor: const Color(0xFF06d6a0),
              icon: const Icon(Icons.add_alert, color: Color(0xFF1c1c1c)),
              label: const Text(
                'Report Incident',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1c1c1c),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: Color(0xFFf5f6fa),
          ),
        ),
      ],
    );
  }

  void _showReportIncidentAtLocation(LatLng location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportIncidentSheet(
        currentLocation: location,
        onIncidentReported: () {
          _loadIncidents();
        },
      ),
    );
  }
}

// Report Incident Bottom Sheet
class ReportIncidentSheet extends StatefulWidget {
  final LatLng currentLocation;
  final VoidCallback onIncidentReported;

  const ReportIncidentSheet({
    super.key,
    required this.currentLocation,
    required this.onIncidentReported,
  });

  @override
  State<ReportIncidentSheet> createState() => _ReportIncidentSheetState();
}

class _ReportIncidentSheetState extends State<ReportIncidentSheet> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedType = 'accident';
  String _selectedSeverity = 'Minor';
  int _selectedDuration = 30; // minutes

  final List<Map<String, dynamic>> _incidentTypes = [
    {
      'value': 'accident',
      'label': 'Accident',
      'icon': 'assets/icons/accident.png',
    },
    {
      'value': 'roadwork',
      'label': 'Road Work',
      'icon': 'assets/icons/roadwork.png',
    },
    {'value': 'event', 'label': 'Event', 'icon': 'assets/icons/event.png'},
  ];

  final List<String> _severityLevels = [
    'Minor',
    'Moderate',
    'Severe',
    'Critical',
  ];
  final List<Map<String, dynamic>> _durations = [
    {'value': 5, 'label': '5 minutes'},
    {'value': 15, 'label': '15 minutes'},
    {'value': 30, 'label': '30 minutes'},
    {'value': 60, 'label': '1 hour'},
    {'value': 240, 'label': '4 hours'},
    {'value': -1, 'label': 'Unknown'},
  ];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      await _supabaseService.reportTrafficIncident(
        incidentType: _selectedType,
        severity: _selectedSeverity,
        latitude: widget.currentLocation.latitude,
        longitude: widget.currentLocation.longitude,
        durationMinutes: _selectedDuration,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onIncidentReported();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident reported successfully!'),
            backgroundColor: Color(0xFF06d6a0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2a2a2a),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF9e9e9e),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Report Incident',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 20),

            // Incident Type
            const Text(
              'Incident Type',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9e9e9e),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: _incidentTypes.map((type) {
                final isSelected = _selectedType == type['value'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = type['value']),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF06d6a0)
                            : const Color(0xFF1c1c1c),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF06d6a0)
                              : const Color(0xFF444444),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            type['value'] == 'accident'
                                ? Icons.car_crash
                                : type['value'] == 'roadwork'
                                ? Icons.construction
                                : Icons.event,
                            size: 32,
                            color: isSelected
                                ? const Color(0xFF1c1c1c)
                                : const Color(0xFFf5f6fa),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            type['label'],
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: isSelected
                                  ? const Color(0xFF1c1c1c)
                                  : const Color(0xFFf5f6fa),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Severity
            const Text(
              'Severity',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9e9e9e),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1c1c1c),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _selectedSeverity,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1c1c1c),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Color(0xFFf5f6fa),
                ),
                items: _severityLevels.map((severity) {
                  return DropdownMenuItem(
                    value: severity,
                    child: Text(severity),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedSeverity = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 20),

            // Duration
            const Text(
              'Expected Duration',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9e9e9e),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1c1c1c),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<int>(
                value: _selectedDuration,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1c1c1c),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Color(0xFFf5f6fa),
                ),
                items: _durations.map<DropdownMenuItem<int>>((duration) {
                  return DropdownMenuItem<int>(
                    value: duration['value'] as int,
                    child: Text(duration['label'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDuration = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 20),

            // Description
            const Text(
              'Description (Optional)',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9e9e9e),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFFf5f6fa),
              ),
              decoration: InputDecoration(
                hintText: 'Add any additional details...',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Color(0xFF9e9e9e),
                ),
                filled: true,
                fillColor: const Color(0xFF1c1c1c),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06d6a0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Color(0xFF1c1c1c),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Report Incident',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1c1c1c),
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
