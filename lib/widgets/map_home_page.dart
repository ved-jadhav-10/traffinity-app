import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/supabase_service.dart';
import '../services/tomtom_service.dart';
import '../services/location_service.dart';
import '../services/cached_tile_provider.dart';
import '../models/location_model.dart';
import '../config/tomtom_config.dart';
import '../screens/auth/sign_in_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _loadUserName();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
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
        });

        // Move map to current location
        _mapController.move(_currentLocation!, 14.0);
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

  Future<void> _selectSearchResult(SearchResult result) async {
    // Save to recent searches
    await _supabaseService.addRecentSearch(
      query: _searchController.text,
      name: result.name,
      latitude: result.latitude,
      longitude: result.longitude,
      address: result.address,
    );

    setState(() {
      _selectedDestination = LatLng(result.latitude, result.longitude);
      _searchResults = [];
      _searchController.text = result.name;
      _showRouteInfo = true;
    });

    // Add destination marker
    _updateMarkers();

    // Move map to show destination
    _mapController.move(_selectedDestination!, 14.0);

    // Clear search focus
    FocusScope.of(context).unfocus();
  }

  void _updateMarkers() {
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

    // Add destination marker
    if (_selectedDestination != null) {
      _markers.add(
        Marker(
          point: _selectedDestination!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
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
    );

    if (route != null && mounted) {
      setState(() {
        _currentRoute = route;
        _routePoints = route.coordinates;
        _isLoadingRoute = false;
      });

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
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  void _recenterMap() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 14.0);
    }
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
              width: 30,
              height: 30,
              child: GestureDetector(
                onTap: () => _showPlaceInfo(result),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 30,
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
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _currentLocation ?? const LatLng(40.7128, -74.0060),
              initialZoom: 14.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=${TomTomConfig.apiKey}',
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
          ),

          // Top section
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Hamburger menu
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1c1c1c),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFFf5f6fa)),
                      onPressed: _showNearbyPlaces,
                      tooltip: 'Nearby Places',
                    ),
                  ),

                  // Greeting
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1c1c1c),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Hello, $_userName',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFf5f6fa),
                      ),
                    ),
                  ),

                  // Favorites & Logout
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1c1c1c),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.favorite,
                            color: Color(0xFF06d6a0),
                          ),
                          onPressed: _showFavorites,
                          tooltip: 'Favorites',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1c1c1c),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.logout,
                            color: Color(0xFFf5f6fa),
                            size: 20,
                          ),
                          onPressed: _logout,
                          tooltip: 'Logout',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Recenter button
          Positioned(
            right: 16,
            bottom: _showRouteInfo ? 320 : 180,
            child: FloatingActionButton(
              onPressed: _recenterMap,
              backgroundColor: const Color(0xFF1c1c1c),
              child: const Icon(Icons.my_location, color: Color(0xFF06d6a0)),
            ),
          ),

          // Route info card (when route is calculated)
          if (_currentRoute != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 180,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1c1c1c),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Route Information',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFf5f6fa),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFFf5f6fa),
                          ),
                          onPressed: _clearRoute,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildRouteInfoItem(
                          Icons.straighten,
                          _currentRoute!.formattedDistance,
                        ),
                        const SizedBox(width: 20),
                        _buildRouteInfoItem(
                          Icons.access_time,
                          _currentRoute!.formattedTime,
                        ),
                        const SizedBox(width: 20),
                        _buildRouteInfoItem(
                          Icons.traffic,
                          _currentRoute!.trafficInfo,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Bottom section
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search bar card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1c1c1c),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Where are you going to?',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFf5f6fa),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFFf5f6fa),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter destination',
                          hintStyle: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Color(0xFF7a7a7a),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF2a2a2a),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF3a3a3a),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF3a3a3a),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF06d6a0),
                              width: 2,
                            ),
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
                              : null,
                        ),
                      ),

                      // Search results
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2a2a2a),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              return ListTile(
                                leading: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF06d6a0),
                                ),
                                title: Text(
                                  result.name,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFFf5f6fa),
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  result.address,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF9e9e9e),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectSearchResult(result),
                              );
                            },
                          ),
                        ),

                      // Get Directions button
                      if (_selectedDestination != null && _currentRoute == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingRoute
                                  ? null
                                  : _getDirections,
                              icon: _isLoadingRoute
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Color(0xFF1c1c1c),
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.directions),
                              label: Text(
                                _isLoadingRoute
                                    ? 'Loading...'
                                    : 'Get Directions',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06d6a0),
                                foregroundColor: const Color(0xFF1c1c1c),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Bottom Navigation Bar
                Container(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoItem(IconData icon, String text) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF06d6a0), size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFFf5f6fa),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
