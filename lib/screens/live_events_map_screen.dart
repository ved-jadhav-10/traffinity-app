import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:profanity_filter/profanity_filter.dart';
import '../services/live_event_service.dart';
import '../services/location_service.dart';
import '../services/tomtom_service.dart';
import '../models/location_model.dart';
import '../config/tomtom_config.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;

class LiveEventsMapScreen extends StatefulWidget {
  final String city;

  const LiveEventsMapScreen({super.key, required this.city});

  @override
  State<LiveEventsMapScreen> createState() => _LiveEventsMapScreenState();
}

class _LiveEventsMapScreenState extends State<LiveEventsMapScreen> {
  final LiveEventService _eventService = LiveEventService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  List<LiveEvent> _events = [];
  bool _isRefreshing = false;
  String? _selectedFilter;
  LatLng? _userLocation;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _compassHeading = 0.0;
  String? _selectedEventId; // Track selected event for highlighting

  // City coordinates
  final Map<String, Map<String, double>> _cityCoordinates = {
    'Mumbai': {'lat': 19.0760, 'lng': 72.8777},
    'Delhi': {'lat': 28.7041, 'lng': 77.1025},
    'Bangalore': {'lat': 12.9716, 'lng': 77.5946},
    'Pune': {'lat': 18.5204, 'lng': 73.8567},
    'Raipur': {'lat': 21.2514, 'lng': 81.6296},
  };

  @override
  void initState() {
    super.initState();
    _initializeUserLocation();
    _initializeCompass();
    _loadEvents(); // Load events in background
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }

  void _initializeCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (mounted) {
        setState(() {
          _compassHeading = event.heading ?? 0.0;
        });
      }
    });
  }

  void _resetMapRotation() {
    // Reset map rotation to north and recenter to user location
    if (_userLocation != null) {
      _mapController.rotate(0.0);
      _mapController.move(_userLocation!, 14.0);
    }
  }

  Future<void> _initializeUserLocation() async {
    try {
      bool hasPermission = await _locationService.checkAndRequestPermissions();
      if (hasPermission) {
        Position? position = await _locationService.getCurrentLocation();
        if (position != null && mounted) {
          setState(() {
            _userLocation = LatLng(position.latitude, position.longitude);
          });

          // Listen for location updates
          _positionStreamSubscription =
              Geolocator.getPositionStream(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 10, // Update every 10 meters
                ),
              ).listen((Position position) {
                if (mounted) {
                  setState(() {
                    _userLocation = LatLng(
                      position.latitude,
                      position.longitude,
                    );
                  });
                }
              });
        }
      }
    } catch (e) {
      print('Error getting user location: $e');
    }
  }

  // Helper to calculate similarity between two strings
  double _stringSimilarity(String s1, String s2) {
    s1 = s1.toLowerCase();
    s2 = s2.toLowerCase();

    if (s1 == s2) return 1.0;

    int longer = s1.length > s2.length ? s1.length : s2.length;
    if (longer == 0) return 1.0;

    int editDistance = _levenshteinDistance(s1, s2);
    return (longer - editDistance) / longer;
  }

  int _levenshteinDistance(String s1, String s2) {
    List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  List<LiveEvent> _removeDuplicates(List<LiveEvent> events) {
    List<LiveEvent> uniqueEvents = [];

    for (var event in events) {
      bool isDuplicate = false;

      for (var uniqueEvent in uniqueEvents) {
        // Check title similarity (70% threshold)
        double titleSimilarity = _stringSimilarity(
          event.title,
          uniqueEvent.title,
        );

        if (titleSimilarity >= 0.7) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        uniqueEvents.add(event);
      }
    }

    return uniqueEvents;
  }

  Future<void> _loadEvents({bool forceRefresh = false}) async {
    try {
      final events = await _eventService.getCityEvents(
        widget.city,
        forceRefresh: forceRefresh,
        onCacheLoaded: (cachedEvents) async {
          // Display cached events immediately for instant UI
          final uniqueCached = _removeDuplicates(cachedEvents);
          
          // Geocode any missing coordinates from cache
          for (var event in uniqueCached) {
            if (event.latitude == null || event.longitude == null) {
              final coords = await _eventService.geocodeLocation(
                event.location,
                widget.city,
              );
              if (coords != null) {
                event.latitude = coords['latitude'];
                event.longitude = coords['longitude'];
              } else {
                final cityCoords = _cityCoordinates[widget.city];
                event.latitude = cityCoords?['lat'];
                event.longitude = cityCoords?['lng'];
              }
            }
          }
          
          if (mounted) {
            setState(() {
              _events = uniqueCached;
            });
            _addEventMarkers();
            print('⚡ Displaying ${uniqueCached.length} cached events instantly!');
          }
        },
      );

      // Process fresh events from network (might include new events)
      final uniqueEvents = _removeDuplicates(events);

      // Geocode events that don't have coordinates
      for (var event in uniqueEvents) {
        if (event.latitude == null || event.longitude == null) {
          final coords = await _eventService.geocodeLocation(
            event.location,
            widget.city,
          );

          if (coords != null) {
            event.latitude = coords['latitude'];
            event.longitude = coords['longitude'];
          } else {
            // Use city center as fallback
            final cityCoords = _cityCoordinates[widget.city];
            event.latitude = cityCoords?['lat'];
            event.longitude = cityCoords?['lng'];
          }

          // Small delay to avoid rate limiting on geocoding
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (mounted) {
        // Update with fresh events (may include new ones)
        final previousCount = _events.length;
        setState(() {
          _events = uniqueEvents;
        });
        _addEventMarkers();
        
        // Notify user if new events were found
        final newCount = uniqueEvents.length - previousCount;
        if (newCount > 0 && !forceRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🆕 Found $newCount new event${newCount > 1 ? 's' : ''}!'),
              backgroundColor: const Color(0xFF06d6a0),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading events: $e');
    }
  }

  Future<void> _refreshEvents() async {
    setState(() => _isRefreshing = true);
    await _loadEvents(forceRefresh: true); // Force refresh from network
    setState(() => _isRefreshing = false);
  }

  void _addEventMarkers() {
    // Markers will be built in the widget tree
    setState(() {});
  }

  bool _containsProfanity(String text) {
    final filter = ProfanityFilter();
    return filter.hasProfanity(text);
  }

  List<LiveEvent> get _filteredEvents {
    // Filter out expired events (24 hours after start time)
    final now = DateTime.now();
    final activeEvents = _events.where((event) {
      final expiryTime = event.startTime.add(const Duration(hours: 24));
      return expiryTime.isAfter(now);
    }).toList();

    // Apply category filter if selected
    if (_selectedFilter == null) return activeEvents;
    return activeEvents.where((e) => e.eventType == _selectedFilter).toList();
  }

  List<Marker> get _eventMarkers {
    List<Marker> markers = [];

    // Add user location marker first (blue arrow)
    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF06d6a0),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06d6a0).withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 24),
          ),
        ),
      );
    }

    // Add event markers
    markers.addAll(
      _filteredEvents
          .where((event) => event.latitude != null && event.longitude != null)
          .map((event) {
            return Marker(
              point: LatLng(event.latitude!, event.longitude!),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _showEventDetails(event),
                child: Image.asset(
                  'assets/icons/event.png',
                  width: 40,
                  height: 40,
                ),
              ),
            );
          })
          .toList(),
    );

    return markers;
  }

  void _showEventDetails(LiveEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF2a2a2a),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF9e9e9e),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getEventColor(event.eventType).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event.eventType.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _getEventColor(event.eventType),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFf5f6fa),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF06d6a0),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFFf5f6fa),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Date & Time
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Color(0xFF4a90e2),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            'MMM dd, yyyy • h:mm a',
                          ).format(event.startTime),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Color(0xFFf5f6fa),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Attendance
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          color: Color(0xFFffa726),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '~${_formatNumber(event.estimatedAttendance)} attendees expected',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Color(0xFFf5f6fa),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Traffic Impact
                    Row(
                      children: [
                        Icon(
                          Icons.traffic,
                          color: _getTrafficImpactColor(event.trafficImpact),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Traffic Impact: ${event.trafficImpact.toString().split('.').last.toUpperCase()}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getTrafficImpactColor(event.trafficImpact),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF3a3a3a)),
                    const SizedBox(height: 20),

                    // Description
                    if (event.description.isNotEmpty) ...[
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFf5f6fa),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.description,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF9e9e9e),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Source
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1c1c1c),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF3a3a3a)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            event.isUserSubmitted ? Icons.person : Icons.public,
                            color: const Color(0xFF06d6a0),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Source: ${event.source}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF9e9e9e),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEventDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    final attendanceController = TextEditingController();
    final TomTomService tomtomService = TomTomService();
    String selectedType = 'concert';
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1)); // Default to 1 hour from now
    DateTime selectedEndDate = DateTime.now().add(const Duration(hours: 4)); // Default to 4 hours from now
    TrafficImpact selectedImpact = TrafficImpact.medium;
    double? detectedLatitude; // Store detected coordinates
    double? detectedLongitude;
    bool isSearchingLocation = false;
    List<SearchResult> locationSearchResults = [];
    Timer? searchDebounce;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF2a2a2a),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add New Event',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFf5f6fa),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF9e9e9e)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Title
                TextField(
                  controller: titleController,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Event Title',
                    labelStyle: const TextStyle(color: Color(0xFF9e9e9e)),
                    filled: true,
                    fillColor: const Color(0xFF1c1c1c),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: const TextStyle(color: Color(0xFF9e9e9e)),
                    filled: true,
                    fillColor: const Color(0xFF1c1c1c),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Location with search and auto-detect buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: locationController,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFFf5f6fa),
                      ),
                      onChanged: (value) async {
                        // Clear previous coordinates when user types
                        detectedLatitude = null;
                        detectedLongitude = null;
                        
                        // Debounce search
                        if (searchDebounce?.isActive ?? false) {
                          searchDebounce!.cancel();
                        }
                        
                        searchDebounce = Timer(const Duration(milliseconds: 500), () async {
                          if (value.length > 2) {
                            setModalState(() {
                              isSearchingLocation = true;
                            });
                            
                            // Search using TomTom
                            final results = await tomtomService.searchLocations(
                              value,
                              lat: _userLocation?.latitude,
                              lon: _userLocation?.longitude,
                            );
                            
                            setModalState(() {
                              locationSearchResults = results;
                              isSearchingLocation = false;
                            });
                          } else {
                            setModalState(() {
                              locationSearchResults = [];
                              isSearchingLocation = false;
                            });
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Search location',
                        hintText: 'e.g., Gateway of India, Mumbai',
                        hintStyle: const TextStyle(
                          color: Color(0xFF6e6e6e),
                          fontSize: 14,
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF9e9e9e)),
                        filled: true,
                        fillColor: const Color(0xFF1c1c1c),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSearchingLocation)
                              const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF06d6a0),
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.my_location,
                                color: Color(0xFF06d6a0),
                              ),
                              tooltip: 'Use my current location',
                              onPressed: () async {
                        try {
                          // Get current location
                          bool hasPermission = await _locationService
                              .checkAndRequestPermissions();
                          if (!hasPermission) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Location permission denied'),
                                  backgroundColor: Color(0xFFf54748),
                                ),
                              );
                            }
                            return;
                          }

                          final position = await _locationService
                              .getCurrentLocation();
                          if (position == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to get current location',
                                  ),
                                  backgroundColor: Color(0xFFf54748),
                                ),
                              );
                            }
                            return;
                          }

                          // Store coordinates directly
                          detectedLatitude = position.latitude;
                          detectedLongitude = position.longitude;

                          // Try reverse geocoding to get a readable address
                          // Using OpenStreetMap Nominatim reverse geocoding
                          try {
                            final response = await http.get(
                              Uri.parse(
                                'https://nominatim.openstreetmap.org/reverse?'
                                'lat=${position.latitude}&'
                                'lon=${position.longitude}&'
                                'format=json&'
                                'addressdetails=1',
                              ),
                              headers: {'User-Agent': 'Traffinity-App/1.0'},
                            );

                            if (response.statusCode == 200) {
                              final data = json.decode(response.body);
                              String address =
                                  data['display_name'] ??
                                  '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

                              setModalState(() {
                                locationController.text = address;
                              });
                            } else {
                              // Fallback to coordinates
                              setModalState(() {
                                locationController.text =
                                    '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
                              });
                            }
                          } catch (e) {
                            print('Reverse geocoding error: $e');
                            // Fallback to coordinates
                            setModalState(() {
                              locationController.text =
                                  '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
                            });
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Location detected!'),
                                backgroundColor: Color(0xFF06d6a0),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error getting location: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: const Color(0xFFf54748),
                              ),
                            );
                          }
                        }
                      },
                    ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Search results dropdown
                    if (locationSearchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1c1c1c),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF06d6a0).withOpacity(0.3),
                          ),
                        ),
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: locationSearchResults.length,
                          itemBuilder: (context, index) {
                            final result = locationSearchResults[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.location_on,
                                color: Color(0xFF06d6a0),
                                size: 20,
                              ),
                              title: Text(
                                result.name,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFf5f6fa),
                                ),
                              ),
                              subtitle: Text(
                                result.address,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Color(0xFF9e9e9e),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                // Set location from search result
                                setModalState(() {
                                  locationController.text = result.name;
                                  detectedLatitude = result.latitude;
                                  detectedLongitude = result.longitude;
                                  locationSearchResults = [];
                                });
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Event Type
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF1c1c1c),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Event Type',
                    labelStyle: const TextStyle(color: Color(0xFF9e9e9e)),
                    filled: true,
                    fillColor: const Color(0xFF1c1c1c),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items:
                      [
                            'concert',
                            'hackathon',
                            'festival',
                            'conference',
                            'expo',
                            'sports',
                            'other',
                          ]
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.toUpperCase()),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setModalState(() => selectedType = value!);
                  },
                ),
                const SizedBox(height: 16),

                // Estimated Attendance
                TextField(
                  controller: attendanceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Expected Crowd',
                    labelStyle: const TextStyle(color: Color(0xFF9e9e9e)),
                    filled: true,
                    fillColor: const Color(0xFF1c1c1c),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Traffic Impact
                DropdownButtonFormField<TrafficImpact>(
                  value: selectedImpact,
                  dropdownColor: const Color(0xFF1c1c1c),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Traffic Impact',
                    labelStyle: const TextStyle(color: Color(0xFF9e9e9e)),
                    filled: true,
                    fillColor: const Color(0xFF1c1c1c),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: TrafficImpact.values
                      .map(
                        (impact) => DropdownMenuItem(
                          value: impact,
                          child: Text(
                            impact.toString().split('.').last.toUpperCase(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setModalState(() => selectedImpact = value!);
                  },
                ),
                const SizedBox(height: 16),

                // Start Date & Time
                GestureDetector(
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF06d6a0),
                              surface: Color(0xFF2a2a2a),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (pickedDate != null && context.mounted) {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF06d6a0),
                                surface: Color(0xFF2a2a2a),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (pickedTime != null) {
                        setModalState(() {
                          selectedDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                          // Auto-set end date to 3 hours after start
                          selectedEndDate = selectedDate.add(const Duration(hours: 3));
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1c1c1c),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF06d6a0), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Date & Time',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Color(0xFF9e9e9e),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy • h:mm a').format(selectedDate),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Color(0xFFf5f6fa),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Color(0xFF9e9e9e), size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.isEmpty ||
                          locationController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill required fields'),
                            backgroundColor: Color(0xFFf54748),
                          ),
                        );
                        return;
                      }

                      // Check for profanity in title and description
                      if (_containsProfanity(titleController.text) ||
                          _containsProfanity(descriptionController.text)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Inappropriate content detected. Please use respectful language.',
                            ),
                            backgroundColor: Color(0xFFf54748),
                            duration: Duration(seconds: 4),
                          ),
                        );
                        return;
                      }

                      // Prevent creating events in the past
                      if (selectedDate.isBefore(DateTime.now())) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Event date cannot be in the past'),
                            backgroundColor: Color(0xFFf54748),
                          ),
                        );
                        return;
                      }

                      // Use stored coordinates if auto-detected, otherwise geocode the location
                      double? finalLatitude = detectedLatitude;
                      double? finalLongitude = detectedLongitude;

                      // Only geocode if we don't have detected coordinates
                      if (finalLatitude == null || finalLongitude == null) {
                        final coords = await _eventService.geocodeLocation(
                          locationController.text,
                          widget.city,
                        );
                        finalLatitude = coords?['latitude'];
                        finalLongitude = coords?['longitude'];
                      }

                      final event = LiveEvent(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text,
                        description: descriptionController.text,
                        location: locationController.text,
                        city: widget.city,
                        startTime: selectedDate,
                        endTime: selectedEndDate,
                        source: 'User Submitted',
                        sourceUrl: '',
                        eventType: selectedType,
                        estimatedAttendance:
                            int.tryParse(attendanceController.text) ?? 200,
                        trafficImpact: selectedImpact,
                        latitude: finalLatitude,
                        longitude: finalLongitude,
                        isUserSubmitted: true,
                      );

                      final success = await _eventService.submitUserEvent(
                        event,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        if (success) {
                          // Add event to local list immediately
                          setState(() {
                            _events.add(event);
                          });
                          _addEventMarkers();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Event added successfully!'),
                              backgroundColor: Color(0xFF06d6a0),
                            ),
                          );
                          
                          // Refresh in background to sync with server
                          _refreshEvents();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to add event'),
                              backgroundColor: Color(0xFFf54748),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06d6a0),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit Event',
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cityCoords = _cityCoordinates[widget.city]!;

    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1c1c1c),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFf5f6fa)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.city} Events',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFf5f6fa),
          ),
        ),
        actions: [
          // Filter
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Color(0xFFf5f6fa)),
            color: const Color(0xFF2a2a2a),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value == 'all' ? null : value;
              });
              _addEventMarkers();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text(
                  'All Events',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                ),
              ),
              const PopupMenuItem(
                value: 'concert',
                child: Text(
                  'Concerts',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                ),
              ),
              const PopupMenuItem(
                value: 'hackathon',
                child: Text(
                  'Hackathons',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                ),
              ),
              const PopupMenuItem(
                value: 'festival',
                child: Text(
                  'Festivals',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                ),
              ),
              const PopupMenuItem(
                value: 'conference',
                child: Text(
                  'Conferences',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                ),
              ),
            ],
          ),
          // Refresh
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF06d6a0),
                    ),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF06d6a0)),
            onPressed: _isRefreshing ? null : _refreshEvents,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Flutter Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(cityCoords['lat']!, cityCoords['lng']!),
              initialZoom: 12.0,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.tomtom.com/map/1/tile/basic/night/{z}/{x}/{y}.png?key=${TomTomConfig.apiKey}',
                userAgentPackageName: 'com.traffinity.app',
              ),
              MarkerLayer(markers: _eventMarkers),
            ],
          ),

          // Event count banner
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06d6a0), Color(0xFF05b48a)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, color: Colors.black, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_filteredEvents.length} Live Events',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Compass button for recentering (moved higher)
          Positioned(
            bottom: 200, // Moved higher to avoid overlap with cards
            left: 16,
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
                iconSize: 40,
                onPressed: _resetMapRotation,
                icon: Transform.rotate(
                  angle: -_compassHeading * (math.pi / 180),
                  child: Image.asset(
                    'assets/icons/compass.png',
                    width: 40,
                    height: 40,
                    color: const Color(0xFF06d6a0),
                  ),
                ),
                tooltip: 'Compass - Recenter & Reset North',
              ),
            ),
          ),

          // Add event button (moved higher to avoid overlap with slider)
          Positioned(
            bottom: 200, // Moved higher to avoid overlap with cards
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _showAddEventDialog,
              backgroundColor: const Color(0xFF06d6a0),
              icon: const Icon(Icons.add, color: Color.fromARGB(255, 0, 0, 0)),
              label: const Text(
                'Add Event',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // Horizontal event slider at bottom (static, always visible)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 175, // Increased height for taller event cards
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF1c1c1c).withOpacity(0.9),
                    const Color(0xFF1c1c1c),
                  ],
                ),
              ),
              child: _events.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2a2a2a),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF06d6a0),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Loading events...',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Color(0xFF9e9e9e),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filteredEvents.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2a2a2a),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No events found',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Color(0xFF9e9e9e),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _filteredEvents.length,
                      itemBuilder: (context, index) {
                        final event = _filteredEvents[index];
                        return _buildEventCard(event);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(LiveEvent event) {
    final isSelected = _selectedEventId == event.id;

    return GestureDetector(
      onTap: () {
        // Update selected event
        setState(() {
          _selectedEventId = event.id;
        });

        // Animate map to event location
        if (event.latitude != null && event.longitude != null) {
          final latLng = LatLng(event.latitude!, event.longitude!);
          // Use Future.microtask to ensure the map controller is ready
          Future.microtask(() {
            _mapController.move(latLng, 15.0);
          });
        }

        // Show event details modal
        _showEventDetails(event);
      },
      child: Container(
        width: 280, // Optimized width
        height: 145, // Increased height for better content display
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? _getEventColor(event.eventType).withOpacity(0.15)
              : const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _getEventColor(event.eventType)
                : _getEventColor(event.eventType).withOpacity(0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? _getEventColor(event.eventType).withOpacity(0.4)
                  : _getEventColor(event.eventType).withOpacity(0.2),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getEventColor(event.eventType),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  event.eventType.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Event title - compact
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFf5f6fa),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              // Location and Time in one row
              Row(
                children: [
                  const Icon(Icons.place, color: Color(0xFF9e9e9e), size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Color(0xFF9e9e9e),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Color(0xFF9e9e9e),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, hh:mm a').format(event.startTime),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: Color(0xFF9e9e9e),
                        ),
                      ),
                    ],
                  ),
                  // Tap indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06d6a0).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TAP',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF06d6a0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'concert':
        return const Color(0xFFe91e63);
      case 'hackathon':
        return const Color(0xFF2196f3);
      case 'festival':
        return const Color(0xFFffa726);
      case 'conference':
        return const Color(0xFF9c27b0);
      case 'expo':
        return const Color(0xFF00bcd4);
      case 'sports':
        return const Color(0xFF4caf50);
      default:
        return const Color(0xFF9e9e9e);
    }
  }

  Color _getTrafficImpactColor(TrafficImpact impact) {
    switch (impact) {
      case TrafficImpact.low:
        return const Color(0xFF06d6a0);
      case TrafficImpact.medium:
        return const Color(0xFFffa726);
      case TrafficImpact.high:
        return const Color(0xFFf54748);
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}
