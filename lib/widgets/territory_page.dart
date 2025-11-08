import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../screens/collections/collections_screen.dart';
import '../screens/city_incident_map_screen.dart';
import '../screens/live_events_map_screen.dart';
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
                  'Explore, discover more, check city updates, and save memories.',
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
                  color: const Color(0xFF06d6a0),
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

                // 2. Live Events (NEW) - Always show, load in background
                _buildFeatureCard(
                  icon: Icons.event,
                  title: 'Live Events',
                  description: _isLoadingEvents
                      ? 'Loading events happening now...'
                      : (_liveEventsCount > 0
                            ? '$_liveEventsCount event${_liveEventsCount > 1 ? 's' : ''} happening now - concerts, hackathons, festivals & more!'
                            : 'Discover concerts, hackathons, festivals & more!'),
                  color: const Color(0xFFAB47BC),
                  onTap: () {
                    final city = _currentLocation != null
                        ? _getCityFromLocation(_currentLocation!)
                        : 'Mumbai'; // Default to Mumbai
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LiveEventsMapScreen(city: city),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 3. Collections
                _buildFeatureCard(
                  icon: Icons.collections,
                  title: 'Collections',
                  description: 'Organize places into custom collections.',
                  color: const Color(0xFFf54728),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CollectionsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 4. Explore Nearby
                _buildFeatureCard(
                  icon: Icons.explore,
                  title: 'Explore Nearby',
                  description: 'Discover interesting places around you.',
                  color: const Color(0xFFffa726),
                  onTap: widget.onExploreNearby,
                ),
                const SizedBox(height: 16),

                // 5. Our Services
                _buildFeatureCard(
                  icon: Icons.business_center,
                  title: 'Our Services',
                  description:
                      'Check our website for more services and features!',
                  color: const Color(0xFF4a90e2),
                  onTap: _openWebsite,
                ),
                const SizedBox(height: 32),

                // Coming Soon Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF06d6a0), Color(0xFF05b48a)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.construction,
                        size: 48,
                        color: Color(0xFF1c1c1c),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Coming Soon',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1c1c1c),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Get ready to explore and save your world!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF1c1c1c),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100), // Extra padding for bottom nav
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openWebsite() async {
    final url = Uri.parse('https://github.com/harshilbiyani');

    // Show confirmation dialog
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2a2a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'External Link',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFFf5f6fa),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'You will be redirected outside our app to view our services.',
            style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF9e9e9e)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF9e9e9e),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06d6a0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF1c1c1c),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    // If user confirmed, open the URL
    if (shouldOpen == true) {
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        // Show error if URL can't be opened
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open website: $e'),
              backgroundColor: const Color(0xFFf54748),
            ),
          );
        }
      }
    }
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
