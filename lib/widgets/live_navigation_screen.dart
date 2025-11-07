import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:async';
import '../models/location_model.dart';
import '../models/traffic_model.dart';
import '../services/navigation_service.dart';
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
  final FlutterTts _flutterTts = FlutterTts();
  final MapController _mapController = MapController();

  StreamSubscription<NavigationState>? _navigationSubscription;
  StreamSubscription<String>? _voiceSubscription;
  StreamSubscription? _compassSubscription;

  NavigationState? _currentState;
  RouteInstruction? _currentInstruction;
  RouteInstruction? _nextInstruction;
  bool _isMuted = false;
  double _heading = 0.0;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _startNavigation();
    _startCompass();
  }

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    _voiceSubscription?.cancel();
    _compassSubscription?.cancel();
    _navigationService.stopNavigation();
    _flutterTts.stop();
    super.dispose();
  }

  void _startCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted && event.heading != null) {
        setState(() {
          _heading = event.heading!;
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
    _navigationSubscription =
        _navigationService.navigationStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
          _currentInstruction = _navigationService.getCurrentInstruction();
          _nextInstruction = _navigationService.getNextInstruction();
          
          // Update current position for map
          _currentPosition = state.currentPosition;
          // Center map on current position with rotation
          _mapController.move(_currentPosition!, 17.0);
          _mapController.rotate(-_heading);
        });
      }
    });

    // Listen to voice guidance
    _voiceSubscription =
        _navigationService.voiceGuidanceStream.listen((message) {
      if (!_isMuted) {
        _speak(message);
      }
    });
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    if (_isMuted) {
      _flutterTts.stop();
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
          child: Column(
            children: [
              // Top info bar
              _buildTopBar(),

              // Main navigation display
              Expanded(
                child: _buildNavigationDisplay(),
              ),

              // Bottom: Compact instruction card + controls
              _buildBottomSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ETA
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentState?.eta ?? '--:--',
                  style: AppTheme.heading2.copyWith(
                    color: AppTheme.primaryGreen,
                  ),
                ),
                Text(
                  'ETA',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Distance remaining
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _currentState?.remainingDistance ?? '--',
                  style: AppTheme.heading3,
                ),
                Text(
                  'Remaining',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Current speed
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_currentState?.currentSpeed.round() ?? 0}',
                  style: AppTheme.heading3,
                ),
                Text(
                  'km/h',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition!,
        initialZoom: 17.5,
        minZoom: 10.0,
        maxZoom: 20.0,
        initialRotation: -_heading,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
        keepAlive: true,
      ),
      children: [
        // TomTom Dark Mode Raster Tiles (guaranteed to work)
        TileLayer(
          urlTemplate: 'https://api.tomtom.com/map/1/tile/basic/night/{z}/{x}/{y}.png?key=${TomTomConfig.apiKey}',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.traffinity.app',
          retinaMode: true,
        ),

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

        // Car marker - centered and always visible
        MarkerLayer(
          rotate: false,
          markers: [
            Marker(
              point: _currentPosition!,
              width: 70,
              height: 70,
              alignment: Alignment.center,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.6),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.navigation,
                  color: AppTheme.primaryGreen,
                  size: 42,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    if (_currentInstruction == null) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          border: Border(
            top: BorderSide(color: AppTheme.borderColor, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              onPressed: null,
              icon: Icon(
                Icons.volume_up,
                color: AppTheme.textSecondary,
                size: AppTheme.iconSizeXL,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final shouldExit = await _showExitDialog();
                if (shouldExit == true && mounted) {
                  widget.onEndNavigation();
                }
              },
              icon: const Icon(Icons.close),
              label: Text('End', style: AppTheme.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              )),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXXL,
                  vertical: AppTheme.spacingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
              ),
            ),
            IconButton(
              onPressed: null,
              icon: Icon(
                Icons.map,
                color: AppTheme.textSecondary,
                size: AppTheme.iconSizeXL,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Off-route warning (if applicable)
          if (_currentState?.isOnRoute == false)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
                vertical: AppTheme.spacingS,
              ),
              color: AppTheme.warningOrange,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: AppTheme.iconSizeM),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'Off route - Recalculating...',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Compact instruction display
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingL,
              AppTheme.spacingM,
              AppTheme.spacingL,
              AppTheme.spacingS,
            ),
            child: Row(
              children: [
                // Maneuver icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Icon(
                    _getManeuverIcon(_currentInstruction!.maneuver),
                    color: Colors.white,
                    size: AppTheme.iconSizeL,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                
                // Distance and instruction
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentState?.nextTurnDistance ?? '--',
                        style: AppTheme.heading3.copyWith(
                          color: AppTheme.primaryGreen,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        _currentInstruction!.instruction,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Next instruction preview (compact)
          if (_nextInstruction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingL,
                0,
                AppTheme.spacingL,
                AppTheme.spacingS,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 60), // Align with text above
                  Text(
                    'Then ',
                    style: AppTheme.bodySmall.copyWith(fontSize: 11),
                  ),
                  Icon(
                    _getManeuverIcon(_nextInstruction!.maneuver),
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Expanded(
                    child: Text(
                      _nextInstruction!.instruction,
                      style: AppTheme.bodySmall.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Divider
          Divider(
            color: AppTheme.borderColor,
            height: 1,
            thickness: 1,
          ),

          // Bottom controls
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingL,
              vertical: AppTheme.spacingM,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Mute button
                IconButton(
                  onPressed: _toggleMute,
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: _isMuted ? AppTheme.textSecondary : AppTheme.primaryGreen,
                    size: AppTheme.iconSizeL,
                  ),
                  tooltip: _isMuted ? 'Unmute' : 'Mute',
                ),

                // End navigation button
                ElevatedButton.icon(
                  onPressed: () async {
                    final shouldExit = await _showExitDialog();
                    if (shouldExit == true && mounted) {
                      widget.onEndNavigation();
                    }
                  },
                  icon: const Icon(Icons.close, size: 18),
                  label: Text('End', style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                  ),
                ),

                // Overview button
                IconButton(
                  onPressed: () {
                    // TODO: Show route overview
                  },
                  icon: const Icon(
                    Icons.map,
                    color: AppTheme.primaryGreen,
                    size: AppTheme.iconSizeL,
                  ),
                  tooltip: 'Overview',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text(
          'End Navigation?',
          style: AppTheme.heading3,
        ),
        content: Text(
          'Are you sure you want to end navigation?',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'End',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
