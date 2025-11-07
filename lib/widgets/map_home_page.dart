import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'dart:math' as math;
import '../services/supabase_service.dart';
import '../services/tomtom_service.dart';
import '../services/location_service.dart';
import '../services/cached_tile_provider.dart';
import '../models/location_model.dart';
import '../config/tomtom_config.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/profile/profile_screen.dart';
import 'transport_page.dart';
import 'territory_page.dart';

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TomTomService _tomtomService = TomTomService();
  final LocationService _locationService = LocationService();
  final SupabaseService _supabaseService = SupabaseService();

  LatLng? _currentLocation;
  LatLng? _selectedDestination;
  List<SearchResult> _searchResults = [];
  List<Marker> _markers = [];
  List<LatLng> _routePoints = [];
  RouteInfo? _currentRoute;
  bool _isSearching = false;
  bool _isLoadingRoute = false;
  String _userName = 'User';
  Timer? _searchDebounce;
  int _selectedIndex = 1;
  bool _showRouteInfo = false;
  bool _isMapInitialized = false;
  String _startLocationName = 'My Location';
  String _destinationLocationName = '';
  List<Map<String, dynamic>> _waypoints = []; // List of stops (C, D, etc.)

  // Compass and speech-to-text
  double _compassHeading = 0.0;
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _mapRotation = 0.0;
  late stt.SpeechToText _speechToText;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _loadUserName();
    _initializeCompass();
    _initializeSpeechToText();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _compassSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    // Request location permissions
    bool hasPermission = await _locationService.checkAndRequestPermissions();

    if (hasPermission) {
      // Get current location
      Position? position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isMapInitialized = true;
          _markers.add(
            Marker(
              point: _currentLocation!,
              width: 40,
              height: 40,
              child: Transform.rotate(
                angle: _compassHeading * (math.pi / 180),
                child: const Icon(
                  Icons.navigation,
                  color: Color(0xFF06d6a0),
                  size: 40,
                ),
              ),
            ),
          );
        });

        // Move map to current location
        _mapController.move(_currentLocation!, 14.0);
      }
    } else {
      // If no permission, still mark as initialized to show map
      if (mounted) {
        setState(() {
          _isMapInitialized = true;
        });
      }
    }
  }

  Future<void> _loadUserName() async {
    final firstName = await _supabaseService.getUserFirstName();
    if (mounted) {
      setState(() {
        _userName = firstName;
      });
    }
  }

  void _initializeCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (mounted) {
        setState(() {
          _compassHeading = event.heading ?? 0.0;
          // Update the user location marker rotation if it exists
          _updateUserLocationMarker();
        });
      }
    });
  }

  void _updateUserLocationMarker() {
    if (_currentLocation != null && _currentRoute == null) {
      // Only update the marker when there's no active route
      _markers.removeWhere((marker) => marker.point == _currentLocation);
      _markers.add(
        Marker(
          point: _currentLocation!,
          width: 40,
          height: 40,
          child: Transform.rotate(
            angle: _compassHeading * (math.pi / 180),
            child: const Icon(
              Icons.navigation,
              color: Color(0xFF06d6a0),
              size: 40,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _initializeSpeechToText() async {
    _speechToText = stt.SpeechToText();
    await _speechToText.initialize(
      onError: (error) {
        if (mounted) {
          _showSnackBar('Speech recognition error. Please try again.');
        }
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
          }
        }
      },
    );
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      // Open search sheet first
      _showSearchSheet();

      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (result) {
            if (result.finalResult) {
              _searchController.text = result.recognizedWords;
              _onSearchChanged(result.recognizedWords);
              setState(() => _isListening = false);
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          localeId: 'en_US',
        );
      } else {
        _showSnackBar('Speech recognition not available. Please try again.');
      }
    }
  }

  void _resetMapRotation() {
    // Reset map rotation to north and recenter
    if (_currentLocation != null) {
      setState(() {
        _mapRotation = 0.0;
      });
      _mapController.rotate(0.0);
      _mapController.move(_currentLocation!, 14.0);
    }
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    final results = await _tomtomService.searchLocations(
      query,
      lat: _currentLocation?.latitude,
      lon: _currentLocation?.longitude,
    );

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _selectSearchResult(
    SearchResult result, {
    bool isEditingStart = false,
  }) async {
    // Save to recent searches
    await _supabaseService.addRecentSearch(
      query: _searchController.text,
      name: result.name,
      latitude: result.latitude,
      longitude: result.longitude,
      address: result.address,
    );

    if (isEditingStart) {
      // Editing start location (A)
      setState(() {
        _currentLocation = LatLng(result.latitude, result.longitude);
        _startLocationName = result.name;
        _searchResults = [];
        _searchController.clear();
      });

      // Update markers and recalculate route if destination exists
      _updateMarkers();
      if (_selectedDestination != null) {
        await _getDirections();
      }
    } else {
      // Setting destination (B)
      setState(() {
        _selectedDestination = LatLng(result.latitude, result.longitude);
        _searchResults = [];
        _searchController.text = result.name;
        _showRouteInfo = true;
        _destinationLocationName = result.name;
      });

      // Add destination marker
      _updateMarkers();

      // Move map to show destination
      _mapController.move(_selectedDestination!, 14.0);

      // Clear search focus
      FocusScope.of(context).unfocus();

      // Automatically calculate route
      await _getDirections();
    }
  }

  void _updateMarkers() {
    _markers.clear();

    // Add start location marker with number 1
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          point: _currentLocation!,
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF06d6a0),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Center(
              child: Text(
                '1',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Add waypoint markers with numbers 2, 3, 4, etc.
    for (int i = 0; i < _waypoints.length; i++) {
      final waypoint = _waypoints[i];
      _markers.add(
        Marker(
          point: LatLng(waypoint['lat'], waypoint['lng']),
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFffa726),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                '${i + 2}', // Start from 2 since 1 is the start location
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Add destination marker with final number
    if (_selectedDestination != null) {
      final finalNumber =
          2 + _waypoints.length; // 1 (start) + waypoints + destination
      _markers.add(
        Marker(
          point: _selectedDestination!,
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFf54748),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                '$finalNumber',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _getDirections() async {
    if (_currentLocation == null || _selectedDestination == null) {
      _showSnackBar('Please select a destination first');
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    final route = await _tomtomService.calculateRoute(
      startLat: _currentLocation!.latitude,
      startLon: _currentLocation!.longitude,
      endLat: _selectedDestination!.latitude,
      endLon: _selectedDestination!.longitude,
      waypoints: _waypoints.isNotEmpty ? _waypoints : null,
    );

    if (route != null && mounted) {
      setState(() {
        _currentRoute = route;
        _routePoints = route.coordinates;
        _isLoadingRoute = false;
      });

      // Update markers after route calculation
      _updateMarkers();

      // Fit bounds to show entire route
      _fitRouteBounds();
    } else {
      setState(() {
        _isLoadingRoute = false;
      });
      _showSnackBar('Failed to calculate route');
    }
  }

  void _fitRouteBounds() {
    if (_routePoints.isEmpty) return;

    double minLat = _routePoints[0].latitude;
    double maxLat = _routePoints[0].latitude;
    double minLng = _routePoints[0].longitude;
    double maxLng = _routePoints[0].longitude;

    for (var point in _routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(
          top: 200, // Account for location bar
          bottom: 250, // Account for bottom slider
          left: 50,
          right: 50,
        ),
      ),
    );
  }

  Future<void> _showNearbyPlaces() async {
    if (_currentLocation == null) {
      _showSnackBar('Location not available');
      return;
    }

    final category = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1c1c1c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildNearbyCategoriesSheet(),
    );

    if (category != null) {
      _searchNearbyPlaces(category);
    }
  }

  Widget _buildNearbyCategoriesSheet() {
    final categories = [
      {
        'name': 'Gas Stations',
        'icon': Icons.local_gas_station,
        'query': 'petrol station',
      },
      {'name': 'Restaurants', 'icon': Icons.restaurant, 'query': 'restaurant'},
      {'name': 'Parking', 'icon': Icons.local_parking, 'query': 'parking'},
      {
        'name': 'EV Charging',
        'icon': Icons.ev_station,
        'query': 'electric vehicle charging station',
      },
      {'name': 'ATMs', 'icon': Icons.atm, 'query': 'atm'},
      {'name': 'Hotels', 'icon': Icons.hotel, 'query': 'hotel'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nearby Places',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFFf5f6fa),
            ),
          ),
          const SizedBox(height: 20),
          ...categories.map(
            (cat) => ListTile(
              leading: Icon(
                cat['icon'] as IconData,
                color: const Color(0xFF06d6a0),
              ),
              title: Text(
                cat['name'] as String,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFFf5f6fa),
                ),
              ),
              onTap: () => Navigator.pop(context, cat['query']),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to get icon path for each category
  String _getCategoryIcon(String category) {
    switch (category) {
      case 'petrol_station':
        return 'assets/images/petrol-pump.png';
      case 'restaurant':
        return 'assets/images/restaurant.png';
      case 'electric_vehicle_station':
        return 'assets/images/charging-station.png';
      case 'parking':
        return 'assets/images/parking.png';
      case 'hotel':
        return 'assets/images/hotel.png';
      case 'atm':
        return 'assets/images/atm.png';
      case 'hospital':
        return 'assets/images/hospital.png';
      default:
        return 'assets/images/atm.png'; // fallback icon
    }
  }

  Future<void> _searchNearbyPlaces(String category) async {
    if (_currentLocation == null) return;

    final results = await _tomtomService.searchNearbyPlaces(
      lat: _currentLocation!.latitude,
      lon: _currentLocation!.longitude,
      category: category,
    );

    if (results.isNotEmpty && mounted) {
      setState(() {
        _markers.clear();

        // Add current location marker
        if (_currentLocation != null) {
          _markers.add(
            Marker(
              point: _currentLocation!,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.my_location,
                color: Color(0xFF06d6a0),
                size: 40,
              ),
            ),
          );
        }

        // Add markers for nearby places
        for (var result in results) {
          _markers.add(
            Marker(
              point: LatLng(result.latitude, result.longitude),
              width: 35,
              height: 35,
              child: GestureDetector(
                onTap: () => _showPlaceInfo(result),
                child: Image.asset(
                  _getCategoryIcon(category),
                  width: 35,
                  height: 35,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        }
      });

      _showSnackBar('Found ${results.length} places nearby');
    }
  }

  void _showPlaceInfo(SearchResult place) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1c1c1c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.name,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              place.address,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFF9e9e9e),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedDestination = LatLng(
                          place.latitude,
                          place.longitude,
                        );
                        _searchController.text = place.name;
                      });
                      _updateMarkers();
                      _getDirections();
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06d6a0),
                      foregroundColor: const Color(0xFF1c1c1c),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    _addToFavorites(place);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2a2a2a),
                    foregroundColor: const Color(0xFFf5f6fa),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToFavorites(SearchResult place) async {
    final success = await _supabaseService.addFavoriteLocation(
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      address: place.address,
      category: place.category,
    );

    if (success) {
      _showSnackBar('Added to favorites');
    } else {
      _showSnackBar('Failed to add to favorites');
    }
  }

  Future<void> _showFavorites() async {
    final favorites = await _supabaseService.getFavoriteLocations();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1c1c1c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Favorite Locations',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: favorites.isEmpty
                  ? const Center(
                      child: Text(
                        'No favorite locations yet',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Color(0xFF9e9e9e),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final fav = favorites[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.favorite,
                            color: Color(0xFF06d6a0),
                          ),
                          title: Text(
                            fav['name'],
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color(0xFFf5f6fa),
                            ),
                          ),
                          subtitle: Text(
                            fav['address'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF9e9e9e),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await _supabaseService.removeFavoriteLocation(
                                fav['id'],
                              );
                              Navigator.pop(context);
                              _showFavorites();
                            },
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _selectedDestination = LatLng(
                                fav['latitude'],
                                fav['longitude'],
                              );
                              _searchController.text = fav['name'];
                            });
                            _updateMarkers();
                            _mapController.move(_selectedDestination!, 14.0);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _routePoints = [];
      _currentRoute = null;
      _selectedDestination = null;
      _destinationLocationName = '';
      _waypoints.clear(); // Clear all waypoints
      _searchController.clear();
      _showRouteInfo = false;
      _updateMarkers();
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2a2a2a),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Build favorite card for horizontal slider
  Widget _buildFavoriteCard(
    Map<String, dynamic> favorite,
    bool isEditingStart,
    VoidCallback onClose,
  ) {
    return GestureDetector(
      onTap: () {
        _selectLocationFromHistory(favorite, isEditingStart: isEditingStart);
        onClose();
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3a3a3a), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06d6a0).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFF06d6a0),
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              favorite['name'],
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (favorite['address'] != null)
              Text(
                favorite['address'],
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Color(0xFF9e9e9e),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  // Show all favorites in a popup
  Future<void> _showAllFavoritesPopup() async {
    final favorites = await _supabaseService.getFavoriteLocations();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1c1c1c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'All Favorite Places',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFf5f6fa),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF9e9e9e)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: favorites.isEmpty
                  ? const Center(
                      child: Text(
                        'No favorite locations yet',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Color(0xFF9e9e9e),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final fav = favorites[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.favorite,
                            color: Color(0xFF06d6a0),
                          ),
                          title: Text(
                            fav['name'],
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color(0xFFf5f6fa),
                            ),
                          ),
                          subtitle: Text(
                            fav['address'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF9e9e9e),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await _supabaseService.removeFavoriteLocation(
                                fav['id'],
                              );
                              Navigator.pop(context);
                              _showAllFavoritesPopup();
                            },
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _selectedDestination = LatLng(
                                fav['latitude'],
                                fav['longitude'],
                              );
                              _searchController.text = fav['name'];
                              _destinationLocationName = fav['name'];
                            });
                            _updateMarkers();
                            _mapController.move(_selectedDestination!, 14.0);
                            _getDirections();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Select location from history (recent searches or favorites)
  Future<void> _selectLocationFromHistory(
    Map<String, dynamic> location, {
    bool isEditingStart = false,
  }) async {
    if (isEditingStart) {
      // Editing start location (A)
      setState(() {
        _currentLocation = LatLng(location['latitude'], location['longitude']);
        _startLocationName = location['name'];
        _searchResults = [];
        _searchController.clear();
      });

      // Update markers and recalculate route if destination exists
      _updateMarkers();
      if (_selectedDestination != null) {
        await _getDirections();
      }
    } else {
      // Setting destination (B)
      setState(() {
        _selectedDestination = LatLng(
          location['latitude'],
          location['longitude'],
        );
        _searchResults = [];
        _searchController.text = location['name'];
        _showRouteInfo = true;
        _destinationLocationName = location['name'];
      });

      // Add destination marker
      _updateMarkers();

      // Move map to show destination
      _mapController.move(_selectedDestination!, 14.0);

      // Automatically calculate route
      await _getDirections();
    }
  }

  // Show search bottom sheet
  void _showSearchSheet({bool isEditingStart = false}) async {
    // Fetch favorites and recent searches before showing the sheet
    final favorites = await _supabaseService.getFavoriteLocations();
    final allRecentSearches = await _supabaseService.getRecentSearches(
      limit: 10,
    );

    // Remove duplicates based on coordinates
    final Map<String, Map<String, dynamic>> uniqueSearches = {};
    for (var search in allRecentSearches) {
      final key = '${search['latitude']}_${search['longitude']}';
      if (!uniqueSearches.containsKey(key)) {
        uniqueSearches[key] = search;
      }
    }
    final recentSearches = uniqueSearches.values.take(3).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final showRecommendations = _searchController.text.isEmpty;

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1c1c1c),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3a3a3a),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Search input
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (query) {
                        _onSearchChanged(query);
                        setModalState(() {}); // Update modal state
                      },
                      autofocus: true,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: Color(0xFFf5f6fa),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search for places',
                        hintStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Color(0xFF7a7a7a),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF06d6a0),
                        ),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF06d6a0),
                                    ),
                                  ),
                                ),
                              )
                            : (_searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: Color(0xFF9e9e9e),
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchResults = [];
                                          _isSearching = false;
                                        });
                                        setModalState(
                                          () {},
                                        ); // Update modal state
                                      },
                                    )
                                  : null),
                        filled: true,
                        fillColor: const Color(0xFF2a2a2a),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // Show recommendations when not searching
                  if (showRecommendations)
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          // Favorite Places Slider
                          if (favorites.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Favorite Places',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFf5f6fa),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showAllFavoritesPopup();
                                    },
                                    child: const Text(
                                      'See all',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        color: Color(0xFF06d6a0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: favorites.length > 5
                                    ? 5
                                    : favorites.length,
                                itemBuilder: (context, index) {
                                  final fav = favorites[index];
                                  return _buildFavoriteCard(
                                    fav,
                                    isEditingStart,
                                    () => Navigator.pop(context),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Recent Searches
                          if (recentSearches.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Text(
                                'Recent Searches',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFf5f6fa),
                                ),
                              ),
                            ),
                            ...recentSearches.map((search) {
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2a2a2a),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.history,
                                    color: Color(0xFF06d6a0),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  search['name'] ?? search['query'],
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFFf5f6fa),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: search['address'] != null
                                    ? Text(
                                        search['address'],
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          color: Color(0xFF9e9e9e),
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                onTap: () {
                                  _selectLocationFromHistory(
                                    search,
                                    isEditingStart: isEditingStart,
                                  );
                                  Navigator.pop(context);
                                },
                              );
                            }).toList(),
                          ],

                          // Empty state if no favorites or recent searches
                          if (favorites.isEmpty && recentSearches.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search,
                                    size: 64,
                                    color: Color(0xFF3a3a3a),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Start typing to search for places',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Color(0xFF9e9e9e),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    // Search results when typing
                    Expanded(
                      child: _searchResults.isEmpty && !_isSearching
                          ? const Center(
                              child: Text(
                                'No results found',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF9e9e9e),
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final result = _searchResults[index];
                                return ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2a2a2a),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Color(0xFF06d6a0),
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    result.name,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Color(0xFFf5f6fa),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    result.address,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Color(0xFF9e9e9e),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    _selectSearchResult(
                                      result,
                                      isEditingStart: isEditingStart,
                                    );
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Show menu drawer
  void _showMenuDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1c1c1c),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3a3a3a),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // User info
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06d6a0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person,
                        color: const Color(0xFF1c1c1c),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $_userName',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFf5f6fa),
                          ),
                        ),
                        const Text(
                          'Welcome to Traffinity',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Color(0xFF9e9e9e),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF3a3a3a), height: 1),

              // Menu items
              ListTile(
                leading: const Icon(Icons.person, color: Color(0xFF06d6a0)),
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                    fontSize: 15,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToProfile();
                },
              ),

              ListTile(
                leading: const Icon(Icons.favorite, color: Color(0xFF06d6a0)),
                title: const Text(
                  'Favorites',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                    fontSize: 15,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showFavorites();
                },
              ),

              const Divider(color: Color(0xFF3a3a3a), height: 1),

              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFF06d6a0)),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                    fontSize: 15,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),

              SizedBox(
                height: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom
                    : 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
    // Reload user name after returning from profile
    _loadUserName();
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text(
          'Logout',
          style: TextStyle(
            color: Color(0xFFf5f6fa),
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Color(0xFF9e9e9e), fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9e9e9e), fontFamily: 'Poppins'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Color(0xFF06d6a0),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await _supabaseService.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SignInScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Logout failed: ${e.toString()}');
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Show different pages based on selected index
          if (_selectedIndex == 0)
            const TransportPage()
          else if (_selectedIndex == 2)
            TerritoryPage(
              onExploreNearby: () {
                // Switch to map page and show nearby places prompt
                setState(() {
                  _selectedIndex = 1;
                });
                // Give a brief moment for the page to switch
                Future.delayed(const Duration(milliseconds: 300), () {
                  _showNearbyPlaces();
                });
              },
            )
          else
            // Traffinity (Map) Page - index 1
            _buildMapPage(),

          // Bottom Navigation Bar (always visible)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1c1c1c),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 12,
                  bottom: MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom
                      : 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavItem(
                      index: 0,
                      image: 'assets/images/transport.png',
                      label: 'Transport',
                    ),
                    _buildNavItem(
                      index: 1,
                      image: 'assets/images/logo.png',
                      label: 'Traffinity',
                    ),
                    _buildNavItem(
                      index: 2,
                      image: 'assets/images/territory.png',
                      label: 'Territory',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPage() {
    return Stack(
      children: [
        // Map with loading indicator
        _isMapInitialized
            ? FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _currentLocation ??
                      const LatLng(
                        20.5937,
                        78.9629,
                      ), // India center as fallback
                  initialZoom: _currentLocation != null ? 14.0 : 5.0,
                  minZoom: 3.0,
                  maxZoom: 18.0,
                  initialRotation: _mapRotation,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.tomtom.com/map/1/tile/basic/night/{z}/{x}/{y}.png?key=${TomTomConfig.apiKey}',
                    userAgentPackageName: 'com.traffinity.app',
                    // Use cached tile provider for faster loading
                    tileProvider: CachedTileProvider(),
                    // Keep tiles in memory for instant display
                    keepBuffer: 5,
                    // Preload tiles around visible area
                    panBuffer: 2,
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 6.0,
                          color: const Color(0xFF06d6a0),
                        ),
                      ],
                    ),
                  MarkerLayer(markers: _markers),
                ],
              )
            : Container(
                color: const Color(0xFF1c1c1c),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF06d6a0)),
                      SizedBox(height: 16),
                      Text(
                        'Loading map...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Color(0xFF9e9e9e),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

        // Top section - Show search bar OR A-B location bar based on route state
        SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show A-B location bar when route is active
              if (_currentRoute != null)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1c1c1c),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header with close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF9e9e9e),
                                size: 18,
                              ),
                              onPressed: _clearRoute,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),

                        // Current Location (Start)
                        Row(
                          children: [
                            const Icon(
                              Icons.my_location,
                              color: Color(0xFF06d6a0),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // Allow editing start location
                                  _showSearchSheet(isEditingStart: true);
                                },
                                child: Text(
                                  _startLocationName,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: Color(0xFFf5f6fa),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Waypoints (stops) - if any
                        ..._waypoints.asMap().entries.map((entry) {
                          int idx = entry.key;
                          Map<String, dynamic> waypoint = entry.value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Color(0xFFffa726),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    waypoint['name'],
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: Color(0xFFf5f6fa),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Move up button (always enabled - can swap with start)
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_upward,
                                    color: Color(0xFF9e9e9e),
                                    size: 18,
                                  ),
                                  onPressed: () => _moveWaypointUp(idx),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                // Move down button (always enabled - can swap with destination)
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_downward,
                                    color: Color(0xFF9e9e9e),
                                    size: 18,
                                  ),
                                  onPressed: () => _moveWaypointDown(idx),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                // Remove button
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Color(0xFF9e9e9e),
                                    size: 18,
                                  ),
                                  onPressed: () => _removeWaypoint(idx),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                        // Destination
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Color(0xFFf54748),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _destinationLocationName,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: Color(0xFFf5f6fa),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        const Divider(color: Color(0xFF3a3a3a), height: 1),
                        const SizedBox(height: 6),

                        // Add Stop button
                        InkWell(
                          onTap: _addWaypoint,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add_circle_outline,
                                  color: Color(0xFF06d6a0),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Add stop',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: Color(0xFF06d6a0),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Search bar (when no route)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1c1c1c),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Search icon
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            Icons.search,
                            color: Color(0xFF06d6a0),
                            size: 24,
                          ),
                        ),

                        // Search input
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              // Open search bottom sheet
                              _showSearchSheet();
                            },
                            child: Container(
                              height: 56,
                              alignment: Alignment.centerLeft,
                              child: const Text(
                                'Search location',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: Color(0xFF9e9e9e),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Mic button
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            icon: Icon(
                              Icons.mic,
                              color: _isListening
                                  ? const Color(0xFF06d6a0)
                                  : const Color(0xFFf5f6fa),
                              size: 24,
                            ),
                            onPressed: _toggleListening,
                            tooltip: 'Voice Search',
                          ),
                        ),

                        // Hamburger menu
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            icon: const Icon(
                              Icons.menu,
                              color: Color(0xFFf5f6fa),
                              size: 24,
                            ),
                            onPressed: _showMenuDrawer,
                            tooltip: 'Menu',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Horizontal category slider (only show when no route)
              if (_currentRoute == null)
                Container(
                  height: 50,
                  margin: const EdgeInsets.only(left: 16, bottom: 8),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCategoryChip(
                        icon: Icons.local_gas_station,
                        label: 'Gas',
                        onTap: () => _searchNearbyPlaces('petrol_station'),
                      ),
                      _buildCategoryChip(
                        icon: Icons.restaurant,
                        label: 'Restaurants',
                        onTap: () => _searchNearbyPlaces('restaurant'),
                      ),
                      _buildCategoryChip(
                        icon: Icons.ev_station,
                        label: 'EV Charging',
                        onTap: () =>
                            _searchNearbyPlaces('electric_vehicle_station'),
                      ),
                      _buildCategoryChip(
                        icon: Icons.local_parking,
                        label: 'Parking',
                        onTap: () => _searchNearbyPlaces('parking'),
                      ),
                      _buildCategoryChip(
                        icon: Icons.hotel,
                        label: 'Hotels',
                        onTap: () => _searchNearbyPlaces('hotel'),
                      ),
                      _buildCategoryChip(
                        icon: Icons.local_atm,
                        label: 'ATMs',
                        onTap: () => _searchNearbyPlaces('atm'),
                      ),
                      _buildCategoryChip(
                        icon: Icons.local_hospital,
                        label: 'Hospitals',
                        onTap: () => _searchNearbyPlaces('hospital'),
                      ),
                      const SizedBox(width: 16), // End padding
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Compass button (replaces My Location button)
        Positioned(
          right: 16,
          bottom: _showRouteInfo ? 320 : 120,
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
              iconSize: 28,
              onPressed: _resetMapRotation,
              icon: Transform.rotate(
                angle: -_compassHeading * (math.pi / 180),
                child: Image.asset(
                  'assets/icons/compass.png',
                  width: 28,
                  height: 28,
                  color: const Color(0xFF06d6a0),
                ),
              ),
              tooltip: 'Compass - Recenter & Reset North',
            ),
          ),
        ),

        // Scrollable bottom slider with route info (when route is calculated)
        if (_currentRoute != null)
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1c1c1c),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 80,
                  ),
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3a3a3a),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Section 1: ETA, Arrival Time, and Action Buttons
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a2a2a),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF3a3a3a),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentRoute!.formattedTime,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF06d6a0),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentRoute!.formattedDistance,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      color: Color(0xFF9e9e9e),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        color: Color(0xFF9e9e9e),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Arrive at ${_getArrivalTime()}',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          color: Color(0xFF9e9e9e),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _showDirectionsSheet();
                                  },
                                  icon: const Icon(Icons.list),
                                  label: const Text('Directions'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFf5f6fa),
                                    side: const BorderSide(
                                      color: Color(0xFF3a3a3a),
                                      width: 1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    // TODO: Start 3D navigation
                                    _showSnackBar('3D Navigation coming soon!');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF06d6a0),
                                    foregroundColor: const Color(0xFF1c1c1c),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'START',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Section 2: Traffic Information and Analysis
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a2a2a),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF3a3a3a),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.traffic,
                                color:
                                    _currentRoute!.trafficInfo
                                        .toLowerCase()
                                        .contains('heavy')
                                    ? Colors.red
                                    : _currentRoute!.trafficInfo
                                          .toLowerCase()
                                          .contains('moderate')
                                    ? Colors.orange
                                    : const Color(0xFF06d6a0),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Traffic Analysis',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFf5f6fa),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            'Current Traffic',
                            _currentRoute!.trafficInfo,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'Route Status',
                            'Optimal route selected',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'Estimated Delay',
                            'No significant delays',
                          ),
                        ],
                      ),
                    ),

                    // Section 3: Territory Prompt
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.explore,
                                color: Color(0xFF1c1c1c),
                                size: 28,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Explore Territory',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1c1c1c),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Discover new places, save your favorite routes, and explore your surroundings with Territory mode.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFF1c1c1c),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                // Navigate to Territory page
                                setState(() {
                                  _selectedIndex = 2;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1c1c1c),
                                side: const BorderSide(
                                  color: Color(0xFF1c1c1c),
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Check it out',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // Waypoint management methods
  void _addWaypoint() {
    // Clear search controller before opening
    _searchController.clear();
    setState(() {
      _searchResults = [];
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1c1c1c),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3a3a3a),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (query) {
                        _onSearchChanged(query);
                        setModalState(() {});
                      },
                      autofocus: true,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: Color(0xFFf5f6fa),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search for a stop',
                        hintStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Color(0xFF7a7a7a),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF06d6a0),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF2a2a2a),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _searchResults.isEmpty && !_isSearching
                        ? const Center(
                            child: Text(
                              'Search for a location',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Color(0xFF9e9e9e),
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2a2a2a),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF06d6a0),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  result.name,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFFf5f6fa),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  result.address,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF9e9e9e),
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  setState(() {
                                    _waypoints.add({
                                      'name': result.name,
                                      'lat': result.latitude,
                                      'lng': result.longitude,
                                    });
                                    _searchResults = [];
                                    _searchController.clear();
                                  });
                                  Navigator.pop(context);
                                  _getDirections(); // Recalculate route with waypoint
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _moveWaypointUp(int index) {
    if (index > 0) {
      // Move waypoint up within waypoints list
      setState(() {
        final waypoint = _waypoints.removeAt(index);
        _waypoints.insert(index - 1, waypoint);
      });
      // Recalculate route after a brief delay to ensure state is updated
      Future.delayed(const Duration(milliseconds: 100), () {
        _getDirections();
      });
    } else if (index == 0 && _currentLocation != null) {
      // Swap first waypoint with start location
      setState(() {
        final waypoint = _waypoints.removeAt(0);

        // Save current start location as waypoint
        _waypoints.insert(0, {
          'lat': _currentLocation!.latitude,
          'lng': _currentLocation!.longitude,
          'name': _startLocationName,
        });

        // Set waypoint as new start
        _currentLocation = LatLng(waypoint['lat'], waypoint['lng']);
        _startLocationName = waypoint['name'];
      });
      // Recalculate route after a brief delay
      Future.delayed(const Duration(milliseconds: 100), () {
        _getDirections();
      });
    }
  }

  void _moveWaypointDown(int index) {
    if (index < _waypoints.length - 1) {
      // Move waypoint down within waypoints list
      setState(() {
        final waypoint = _waypoints.removeAt(index);
        _waypoints.insert(index + 1, waypoint);
      });
      // Recalculate route after a brief delay to ensure state is updated
      Future.delayed(const Duration(milliseconds: 100), () {
        _getDirections();
      });
    } else if (index == _waypoints.length - 1 && _selectedDestination != null) {
      // Swap last waypoint with destination
      setState(() {
        final waypoint = _waypoints.removeAt(_waypoints.length - 1);

        // Save current destination as waypoint
        _waypoints.add({
          'lat': _selectedDestination!.latitude,
          'lng': _selectedDestination!.longitude,
          'name': _destinationLocationName,
        });

        // Set waypoint as new destination
        _selectedDestination = LatLng(waypoint['lat'], waypoint['lng']);
        _destinationLocationName = waypoint['name'];
      });
      // Recalculate route after a brief delay
      Future.delayed(const Duration(milliseconds: 100), () {
        _getDirections();
      });
    }
  }

  void _removeWaypoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
    });
    _getDirections(); // Recalculate route
  }

  void _showDirectionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1c1c1c),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3a3a3a),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Step-by-Step Directions',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFf5f6fa),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF9e9e9e)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Route summary
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2a2a),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          _currentRoute!.formattedTime,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF06d6a0),
                          ),
                        ),
                        const Text(
                          'Duration',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF9e9e9e),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: const Color(0xFF3a3a3a),
                    ),
                    Column(
                      children: [
                        Text(
                          _currentRoute!.formattedDistance,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF06d6a0),
                          ),
                        ),
                        const Text(
                          'Distance',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF9e9e9e),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Directions list (placeholder for now)
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildDirectionStep(
                      icon: Icons.my_location,
                      instruction: 'Start at $_startLocationName',
                      distance: '',
                    ),
                    _buildDirectionStep(
                      icon: Icons.straight,
                      instruction: 'Head toward your destination',
                      distance: '0.5 km',
                    ),
                    _buildDirectionStep(
                      icon: Icons.turn_right,
                      instruction: 'Turn right',
                      distance: '1.2 km',
                    ),
                    _buildDirectionStep(
                      icon: Icons.straight,
                      instruction: 'Continue straight',
                      distance: '2.8 km',
                    ),
                    _buildDirectionStep(
                      icon: Icons.location_on,
                      instruction: 'Arrive at $_destinationLocationName',
                      distance: '',
                      isLast: true,
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionStep({
    required IconData icon,
    required String instruction,
    required String distance,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isLast
                      ? const Color(0xFFf54748)
                      : const Color(0xFF06d6a0),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  color: const Color(0xFF3a3a3a),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    color: Color(0xFFf5f6fa),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (distance.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      distance,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Color(0xFF9e9e9e),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getArrivalTime() {
    if (_currentRoute == null) return '';

    // Parse duration from formatted time (e.g., "25 min" or "1 hr 30 min")
    final timeStr = _currentRoute!.formattedTime;
    int totalMinutes = 0;

    // Extract hours and minutes
    final hourMatch = RegExp(r'(\d+)\s*hr').firstMatch(timeStr);
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(timeStr);

    if (hourMatch != null) {
      totalMinutes += int.parse(hourMatch.group(1)!) * 60;
    }
    if (minMatch != null) {
      totalMinutes += int.parse(minMatch.group(1)!);
    }

    // Add to current time
    final arrivalTime = DateTime.now().add(Duration(minutes: totalMinutes));

    // Format as "3:45 PM"
    final hour = arrivalTime.hour > 12
        ? arrivalTime.hour - 12
        : arrivalTime.hour;
    final period = arrivalTime.hour >= 12 ? 'PM' : 'AM';
    final minute = arrivalTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute $period';
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Color(0xFF9e9e9e),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFf5f6fa),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1c1c1c),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3a3a3a), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF06d6a0), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFFf5f6fa),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String image,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            image,
            width: 32,
            height: 32,
            color: isSelected
                ? const Color(0xFF06d6a0)
                : const Color(0xFFf5f6fa),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF06d6a0)
                  : const Color(0xFFf5f6fa),
            ),
          ),
        ],
      ),
    );
  }
}
