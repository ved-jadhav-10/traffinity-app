import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/city_incident_map_screen.dart';
import '../screens/civic_issue_map_screen.dart';
import '../screens/live_events_map_screen.dart';
import '../screens/parking/parkhub_map_screen.dart';
import '../services/location_service.dart';
import '../services/live_event_service.dart';

class TerritoryPage extends StatefulWidget {
  final VoidCallback? onExploreNearby;

  const TerritoryPage({super.key, this.onExploreNearby});

  @override
  State<TerritoryPage> createState() => _TerritoryPageState();
}

class _TerritoryPageState extends State<TerritoryPage> {
  final LocationService _locationService = LocationService();
  LatLng? _currentLocation;
  int _liveEventsCount = 0;
  bool _isLoadingEvents = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      bool hasPermission = await _locationService.checkAndRequestPermissions();
      if (hasPermission) {
        Position? position = await _locationService.getCurrentLocation();
        if (position != null && mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
          await _loadLiveEventsCount();
        }
      }
    } catch (e) {
      print('Error getting location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    }
  }

  String _getCityFromLocation(LatLng location) {
    final cityCoords = {
      'Mumbai': LatLng(19.0760, 72.8777),
      'Delhi': LatLng(28.7041, 77.1025),
      'Bangalore': LatLng(12.9716, 77.5946),
      'Pune': LatLng(18.5204, 73.8567),
      'Raipur': LatLng(21.2514, 81.6296),
    };

    String closestCity = 'Mumbai';
    double minDistance = double.infinity;

    cityCoords.forEach((city, coords) {
      final distance = const Distance().as(
        LengthUnit.Kilometer,
        location,
        coords,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestCity = city;
      }
    });

    return closestCity;
  }

  Future<void> _loadLiveEventsCount() async {
    if (_currentLocation == null) return;

    try {
      final city = _getCityFromLocation(_currentLocation!);
      final events = await LiveEventService().getCityEvents(city);
      if (mounted) {
        setState(() {
          _liveEventsCount = events.length;
        });
      }
    } catch (e) {
      print('Error loading live events count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a2a2a),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        'assets/images/territory.png',
                        width: 32,
                        height: 32,
                        color: const Color(0xFF06d6a0),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Territory',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFf5f6fa),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Description
                const Text(
                  'Check city updates, report incidents, and manage parking.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Color(0xFF9e9e9e),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Feature Cards Section
                // 1. City Incident Map
                _buildFeatureCard(
                  icon: Icons.report_problem,
                  title: 'City Incident Map',
                  description:
                      'A live map of all traffic jams, accidents, event or weather related delays.',
                  color: const Color(0xFFffa726),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CityIncidentMapScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 2. Civic Issue Map
                _buildFeatureCard(
                  icon: Icons.engineering,
                  title: 'Civic Issue Map',
                  description:
                      'Report civic issues like potholes, garbage collection and more.',
                  color: const Color(0xFF06d6a0),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CivicIssueMapScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 3. Live Events (NEW) - Always show, load in background
                _buildFeatureCard(
                  icon: Icons.event,
                  title: 'Live Events',
                  description: _isLoadingEvents
                      ? 'Loading events happening now...'
                      : (_liveEventsCount > 0
                            ? '$_liveEventsCount event${_liveEventsCount > 1 ? 's' : ''} happening now - concerts, hackathons, festivals & more!'
                            : 'Discover concerts, hackathon, festivals & more!'),
                  color: const Color(0xFFf54248),
                  onTap: () async {
                    // Ensure we have current location before proceeding
                    String city = 'Pune'; // Default to Pune instead of Mumbai
                    
                    if (_currentLocation != null) {
                      city = _getCityFromLocation(_currentLocation!);
                    } else {
                      // Try to get location one more time
                      try {
                        bool hasPermission = await _locationService.checkAndRequestPermissions();
                        if (hasPermission) {
                          Position? position = await _locationService.getCurrentLocation();
                          if (position != null) {
                            final location = LatLng(position.latitude, position.longitude);
                            city = _getCityFromLocation(location);
                          }
                        }
                      } catch (e) {
                        print('Error getting location for events: $e');
                      }
                    }
                    
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LiveEventsMapScreen(city: city),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 4. ParkHub Manager
                _buildFeatureCard(
                  icon: Icons.local_parking,
                  title: 'ParkHub Manager',
                  description: 'Find and book parking spots near you.',
                  color: const Color(0xFF4a90e2),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ParkHubMapScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 100), // Extra padding for bottom nav
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3a3a3a), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFf5f6fa),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Color(0xFF9e9e9e),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF9e9e9e),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
