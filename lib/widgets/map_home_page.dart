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
  bool _isMapInitialized = false;

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
          _isMapInitialized = true;
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

    // Automatically calculate route
    await _getDirections();
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

  // Show search bottom sheet
  void _showSearchSheet() {
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

                  // Search results
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
                                  _selectSearchResult(result);
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

              ListTile(
                leading: const Icon(Icons.explore, color: Color(0xFFf5f6fa)),
                title: const Text(
                  'Nearby Places',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                    fontSize: 15,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showNearbyPlaces();
                },
              ),

              const Divider(color: Color(0xFF3a3a3a), height: 1),

              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFf5f6fa)),
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

          // Top section - Google Maps style search bar
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search bar
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

                // Horizontal category slider (Google Maps style)
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

          // Recenter button
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
                onPressed: _recenterMap,
                icon: const Icon(Icons.my_location, color: Color(0xFF06d6a0)),
                tooltip: 'My Location',
              ),
            ),
          ),

          // Route info card (when route is calculated)
          if (_currentRoute != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1c1c1c),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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

          // Bottom Navigation Bar (kept as is)
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
