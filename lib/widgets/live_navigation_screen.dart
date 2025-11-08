import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/location_model.dart';
import '../models/traffic_model.dart';
import '../services/navigation_service.dart';
import '../services/tomtom_service.dart';
import '../services/weather_service.dart';
import '../services/supabase_service.dart';
import '../config/tomtom_config.dart';
import '../config/app_theme.dart';

class LiveNavigationScreen extends StatefulWidget {
  final RouteInfo route;
  final VoidCallback onEndNavigation;

  const LiveNavigationScreen({
    super.key,
    required this.route,
    required this.onEndNavigation,
  });

  @override
  State<LiveNavigationScreen> createState() => _LiveNavigationScreenState();
}

class _LiveNavigationScreenState extends State<LiveNavigationScreen> {
  final NavigationService _navigationService = NavigationService();
  final TomTomService _tomtomService = TomTomService();
  final WeatherService _weatherService = WeatherService();
  final SupabaseService _supabaseService = SupabaseService();
  final FlutterTts _flutterTts = FlutterTts();
  final MapController _mapController = MapController();

  StreamSubscription<NavigationState>? _navigationSubscription;
  StreamSubscription<String>? _voiceSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  NavigationState? _currentState;
  RouteInstruction? _currentInstruction;
  bool _isMuted = false;
  double _compassHeading = 0.0;
  LatLng? _currentPosition;
  LatLng? _initialMapCenter; // Store initial map center to prevent jumping
  String _originalETA = ''; // Store the original ETA from route

  // Traffic flow data
  List<TrafficFlowSegment> _trafficFlows = [];
  List<Polyline> _trafficPolylines = [];
  Timer? _trafficRefreshTimer;
  
  // Weather data
  WeatherData? _currentWeather;
  Timer? _weatherRefreshTimer;
  
  // Notification tracking
  Set<String> _shownNotifications = {};

  @override
  void initState() {
    super.initState();
    _calculateOriginalETA();
    _initializeTTS();
    _startNavigation();
    _initializeCompass();
    _startTrafficRefresh();
    _startWeatherRefresh();
  }

  void _calculateOriginalETA() {
    // Calculate ETA from the original route (same logic as map_home_page.dart)
    final timeStr = widget.route.formattedTime;
    int totalMinutes = 0;

    // Extract hours and minutes
    final hourMatch = RegExp(r'(\d+)\s*h').firstMatch(timeStr);
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
        : (arrivalTime.hour == 0 ? 12 : arrivalTime.hour);
    final period = arrivalTime.hour >= 12 ? 'PM' : 'AM';
    final minute = arrivalTime.minute.toString().padLeft(2, '0');

    _originalETA = '$hour:$minute $period';
  }

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    _voiceSubscription?.cancel();
    _compassSubscription?.cancel();
    _trafficRefreshTimer?.cancel();
    _weatherRefreshTimer?.cancel();
    _navigationService.stopNavigation();
    _flutterTts.stop();
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

  Future<void> _initializeTTS() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _startNavigation() async {
    // Start navigation service
    await _navigationService.startNavigation(widget.route);

    // Listen to navigation state updates
    _navigationSubscription = _navigationService.navigationStateStream.listen((
      state,
    ) {
      if (mounted) {
        final bool isFirstUpdate = _currentPosition == null;
        
        setState(() {
          _currentState = state;
          _currentInstruction = _navigationService.getCurrentInstruction();

          // Update current position for map
          _currentPosition = state.currentPosition;
          
          // Set initial map center only once to prevent jumping
          if (_initialMapCenter == null) {
            _initialMapCenter = state.currentPosition;
          }
        });
        
        // Load weather data on first position update
        if (isFirstUpdate && _currentPosition != null) {
          _loadWeatherData();
          _loadTrafficData();
        }
      }
    });

    // Listen to voice guidance
    _voiceSubscription = _navigationService.voiceGuidanceStream.listen((
      message,
    ) {
      if (!_isMuted) {
        _speak(message);
      }
    });
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _loadTrafficData() async {
    if (_currentPosition == null) return;

    try {
      // Calculate bounding box around route (20km radius)
      const double kmToDegrees = 0.009;
      final double offset = kmToDegrees * 20;

      final trafficFlows = await _tomtomService.getLiveTrafficFlow(
        minLat: _currentPosition!.latitude - offset,
        minLon: _currentPosition!.longitude - offset,
        maxLat: _currentPosition!.latitude + offset,
        maxLon: _currentPosition!.longitude + offset,
        zoom: 12,
      );

      if (mounted) {
        setState(() {
          _trafficFlows = trafficFlows;
          _buildTrafficPolylines();
        });
      }
    } catch (e) {
      print('Error loading traffic data: $e');
    }
  }

  void _buildTrafficPolylines() {
    _trafficPolylines = _trafficFlows.map((flow) {
      return Polyline(
        points: flow.coordinates,
        color: flow.trafficColor,
        strokeWidth: 4.0,
        borderColor: Colors.black.withOpacity(0.3),
        borderStrokeWidth: 1.0,
      );
    }).toList();
  }

  void _startTrafficRefresh() {
    _trafficRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadTrafficData();
        _checkForSevereTraffic();
      }
    });
  }

  Future<void> _loadWeatherData() async {
    if (_currentPosition == null) return;

    try {
      print('🌤️ Loading weather for position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      
      final weather = await _weatherService.getCurrentWeather(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (mounted && weather != null) {
        print('🌤️ Weather loaded: ${weather.temp}°C, ${weather.description}');
        setState(() {
          _currentWeather = weather;
        });
        _checkForSevereWeather(weather);
      } else {
        print('⚠️ Weather data is null');
      }
    } catch (e) {
      print('Error loading weather data: $e');
    }
  }

  void _startWeatherRefresh() {
    // Refresh weather every 5 minutes
    _weatherRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _loadWeatherData();
      }
    });
  }

  void _checkForSevereTraffic() {
    // Check if there are any severe traffic conditions on route
    for (var flow in _trafficFlows) {
      // Red traffic = severe congestion
      if (flow.trafficColor == Colors.red) {
        final notificationKey = 'severe_traffic_${DateTime.now().hour}';
        if (!_shownNotifications.contains(notificationKey)) {
          _shownNotifications.add(notificationKey);
          _showNotification(
            'Severe Traffic Ahead',
            'Heavy congestion detected on your route',
            Colors.red,
            Icons.traffic,
          );
          if (!_isMuted) {
            _speak('Warning: Severe traffic congestion ahead');
          }
          break;
        }
      }
    }
  }

  void _checkForSevereWeather(WeatherData weather) {
    final impact = _weatherService.calculateWeatherImpact(weather);
    
    // Severe weather conditions
    if (impact >= 0.20) {
      final notificationKey = 'severe_weather_${DateTime.now().hour}';
      if (!_shownNotifications.contains(notificationKey)) {
        _shownNotifications.add(notificationKey);
        
        String condition = '';
        if (weather.rain1h != null && weather.rain1h! > 10) {
          condition = 'Heavy rain';
        } else if (weather.snow1h != null && weather.snow1h! > 5) {
          condition = 'Heavy snow';
        } else if (weather.visibility < 1000) {
          condition = 'Poor visibility';
        } else if (weather.windSpeed > 15) {
          condition = 'Strong winds';
        } else {
          condition = 'Severe weather';
        }
        
        _showNotification(
          '$condition Alert',
          '${weather.description[0].toUpperCase()}${weather.description.substring(1)} - Drive carefully',
          Colors.orange,
          Icons.warning_amber,
        );
        
        if (!_isMuted) {
          _speak('Warning: $condition detected. Please drive carefully');
        }
      }
    }
  }

  void _showNotification(String title, String message, Color color, IconData icon) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _recenterMap() {
    _mapController.rotate(0);
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, _mapController.camera.zoom);
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    if (_isMuted) {
      _flutterTts.stop();
    }
  }

  // Show SOS confirmation and create emergency incident
  Future<void> _showSOSConfirmation() async {
    if (_currentPosition == null) {
      _showNotification(
        'Location Unavailable',
        'Please enable location services.',
        Colors.red,
        Icons.location_off,
      );
      return;
    }

    final shouldReport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: Color(0xFFf54748), size: 28),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Emergency SOS',
                style: TextStyle(
                  color: Color(0xFFf5f6fa),
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'This will report a severe accident at your current location. Emergency services and nearby users will be notified.\n\nAre you sure you want to proceed?',
            style: TextStyle(
              color: Color(0xFF9e9e9e),
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf54748),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Report Emergency',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9e9e9e), fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );

    if (shouldReport == true) {
      await _reportSOSIncident();
    }
  }

  // Report SOS incident to Supabase
  Future<void> _reportSOSIncident() async {
    try {
      // Get user profile for contact details
      final userProfile = await _supabaseService.getUserProfile();
      final phoneNumber = userProfile['phone_number'] ?? '';
      final userName = userProfile['name'] ?? 'User';

      // Create description with contact info if available
      String description = 'EMERGENCY - Accident reported via SOS during navigation';
      if (phoneNumber.isNotEmpty) {
        description += '\nContact: $userName - $phoneNumber';
      } else {
        description += '\nContact: $userName';
      }

      // Report the incident
      await _supabaseService.reportTrafficIncident(
        incidentType: 'accident',
        severity: 'Severe',
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        durationMinutes: 60, // Default to 1 hour
        description: description,
      );

      if (mounted) {
        _showNotification(
          'Emergency Reported',
          'Help is on the way! Nearby users have been notified.',
          AppTheme.primaryGreen,
          Icons.check_circle,
        );

        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2a2a2a),
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF06d6a0), size: 28),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Emergency Reported',
                    style: TextStyle(
                      color: Color(0xFFf5f6fa),
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: const SingleChildScrollView(
              child: Text(
                'Your emergency has been reported. Nearby users and emergency services have been notified of the accident.',
                style: TextStyle(
                  color: Color(0xFF9e9e9e),
                  fontFamily: 'Poppins',
                  fontSize: 14,
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06d6a0),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showNotification(
          'Error',
          'Failed to report emergency: ${e.toString()}',
          Colors.red,
          Icons.error,
        );
      }
    }
  }

  IconData _getManeuverIcon(String maneuver) {
    final maneuverUpper = maneuver.toUpperCase();

    if (maneuverUpper.contains('DEPART') || maneuverUpper.contains('START')) {
      return Icons.my_location;
    } else if (maneuverUpper.contains('ARRIVE') ||
        maneuverUpper.contains('FINISH')) {
      return Icons.location_on;
    } else if (maneuverUpper.contains('LEFT')) {
      if (maneuverUpper.contains('SHARP')) {
        return Icons.turn_sharp_left;
      } else if (maneuverUpper.contains('SLIGHT')) {
        return Icons.turn_slight_left;
      }
      return Icons.turn_left;
    } else if (maneuverUpper.contains('RIGHT')) {
      if (maneuverUpper.contains('SHARP')) {
        return Icons.turn_sharp_right;
      } else if (maneuverUpper.contains('SLIGHT')) {
        return Icons.turn_slight_right;
      }
      return Icons.turn_right;
    } else if (maneuverUpper.contains('UTURN') ||
        maneuverUpper.contains('U_TURN')) {
      return Icons.u_turn_left;
    } else if (maneuverUpper.contains('ROUNDABOUT') ||
        maneuverUpper.contains('ROTARY')) {
      return Icons.roundabout_left;
    } else if (maneuverUpper.contains('STRAIGHT') ||
        maneuverUpper.contains('CONTINUE')) {
      return Icons.straight;
    }

    return Icons.navigation;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await _showExitDialog();
        return shouldExit ?? false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: SafeArea(
          child: Stack(
            children: [
              // Full screen map
              _buildNavigationDisplay(),
              
              // Top instruction card (Google Maps style)
              if (_currentInstruction != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildTopInstructionCard(),
                ),
              
              // Weather and mute buttons (left side, above footer)
              Positioned(
                bottom: 140,
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Weather info
                    if (_currentWeather != null) _buildWeatherCard(),
                    const SizedBox(height: 12),
                    // Mute button
                    _buildMuteButton(),
                  ],
                ),
              ),

              // SOS Button (right side, above compass)
              Positioned(
                right: 16,
                bottom: 222,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFf54748),
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
                    padding: EdgeInsets.zero,
                    iconSize: 48,
                    onPressed: _showSOSConfirmation,
                    icon: const Icon(Icons.warning, size: 40, color: Colors.white),
                    tooltip: 'Emergency SOS - Report Accident',
                  ),
                ),
              ),

              // Compass button (right side, above footer)
              Positioned(
                right: 16,
                bottom: 140,
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
                    onPressed: _recenterMap,
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
              
              // Bottom footer with stats only
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomFooter(),
              ),
              
              // Close button (top right)
              Positioned(
                top: 16,
                right: 16,
                child: _buildCloseButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherCard() {
    final impact = _weatherService.calculateWeatherImpact(_currentWeather!);
    final isSevere = impact >= 0.20; // Severe if 20% or more impact
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getWeatherIcon(_currentWeather!.main),
            color: _getWeatherSeverityColor(_currentWeather!),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${_currentWeather!.temp.round()}°C',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFf5f6fa),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _currentWeather!.description,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFFa4a8b0),
            ),
          ),
          if (isSevere) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.warning_amber,
              color: Colors.orange,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMuteButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleMute,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a2a).withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: _isMuted ? const Color(0xFF666666) : AppTheme.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _isMuted ? 'Unmute' : 'Mute',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _isMuted ? const Color(0xFF666666) : const Color(0xFFf5f6fa),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final shouldExit = await _showExitDialog();
          if (shouldExit == true && mounted) {
            widget.onEndNavigation();
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a2a).withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.close,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildTopInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a).withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Maneuver icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getManeuverIcon(_currentInstruction!.maneuver),
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          
          // Instruction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentState?.nextTurnDistance ?? '--',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentInstruction!.instruction,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Color(0xFFf5f6fa),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomFooter() {
    if (_currentState == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a).withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a).withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // ETA
          _buildStatItem(
            icon: Icons.schedule,
            label: 'ETA',
            value: _originalETA,
            color: AppTheme.primaryGreen,
          ),
          
          // Vertical divider
          Container(
            height: 50,
            width: 1,
            color: const Color(0xFF3a3a3a),
          ),
          
          // Distance
          _buildStatItem(
            icon: Icons.straighten,
            label: 'Distance',
            value: _currentState!.remainingDistance,
            color: Colors.blue,
          ),
          
          // Vertical divider
          Container(
            height: 50,
            width: 1,
            color: const Color(0xFF3a3a3a),
          ),
          
          // Speed
          _buildStatItem(
            icon: Icons.speed,
            label: 'Speed',
            value: '${_currentState!.currentSpeed.round()} km/h',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFf5f6fa),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Color(0xFF9095a0),
          ),
        ),
      ],
    );
  }

  IconData _getWeatherIcon(String main) {
    switch (main.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
      case 'drizzle':
        return Icons.grain;
      case 'snow':
        return Icons.ac_unit;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'mist':
      case 'fog':
        return Icons.blur_on;
      default:
        return Icons.wb_cloudy;
    }
  }

  Color _getWeatherSeverityColor(WeatherData weather) {
    final impact = _weatherService.calculateWeatherImpact(weather);
    
    if (impact >= 0.25) {
      return Colors.red;
    } else if (impact >= 0.15) {
      return Colors.orange;
    } else if (impact >= 0.10) {
      return Colors.yellow.shade700;
    } else {
      return AppTheme.primaryGreen;
    }
  }

  Widget _buildNavigationDisplay() {
    if (_currentInstruction == null || _currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryGreen),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Starting navigation...',
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialMapCenter ?? _currentPosition!,
            initialZoom: 17.5,
            minZoom: 10.0,
            maxZoom: 20.0,
            initialRotation: 0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            keepAlive: true,
          ),
          children: [
            // TomTom Dark Mode Raster Tiles (guaranteed to work)
            TileLayer(
              urlTemplate:
                  'https://api.tomtom.com/map/1/tile/basic/night/{z}/{x}/{y}.png?key=${TomTomConfig.apiKey}',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.traffinity.app',
              retinaMode: true,
            ),

            // Traffic flow polylines
            PolylineLayer(polylines: _trafficPolylines),

            // Route polyline - behind the car marker
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.route.coordinates,
                  strokeWidth: 7.0,
                  color: AppTheme.primaryGreen,
                  borderStrokeWidth: 2.0,
                  borderColor: Colors.black.withOpacity(0.3),
                ),
              ],
            ),

            // Current location marker (car icon - fixed orientation with circle)
            MarkerLayer(
              rotate: false,
              markers: [
                Marker(
                  point: _currentPosition!,
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2a2a2a),
                      border: Border.all(
                        color: AppTheme.primaryGreen,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.navigation,
                      color: AppTheme.primaryGreen,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text('End Navigation?', style: AppTheme.heading3),
        content: Text(
          'Are you sure you want to end navigation?',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'End',
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}
