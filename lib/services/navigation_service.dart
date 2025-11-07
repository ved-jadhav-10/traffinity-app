import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_model.dart';
import '../models/traffic_model.dart';
import 'location_service.dart';
import 'tomtom_service.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final LocationService _locationService = LocationService();
  final TomTomService _tomtomService = TomTomService();

  // Navigation state
  RouteInfo? _currentRoute;
  int _currentInstructionIndex = 0;
  StreamSubscription<Position>? _locationSubscription;
  Position? _lastPosition;
  Position? _lastValidPosition;

  // Stream controller for navigation updates
  final _navigationStateController =
      StreamController<NavigationState>.broadcast();
  Stream<NavigationState> get navigationStateStream =>
      _navigationStateController.stream;

  // Voice guidance state
  final _voiceGuidanceController = StreamController<String>.broadcast();
  Stream<String> get voiceGuidanceStream => _voiceGuidanceController.stream;

  // Constants
  static const double offRouteThreshold = 30.0; // meters
  static const double instructionProximityThreshold = 500.0; // meters
  static const double arrivalThreshold = 50.0; // meters
  static const double accuracyThreshold = 20.0; // meters

  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;

  // Start navigation
  Future<void> startNavigation(RouteInfo route) async {
    if (_isNavigating) {
      await stopNavigation();
    }

    // Get current position first
    final currentPosition = await _locationService.getCurrentLocation();

    if (currentPosition != null) {
      // Update route to start from exact current position
      final currentLatLng = LatLng(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      // Replace first coordinate with current position
      if (route.coordinates.isNotEmpty) {
        route.coordinates[0] = currentLatLng;
      }

      print('🧭 Navigation started from current position: $currentLatLng');
    }

    _currentRoute = route;
    _currentInstructionIndex = 0;
    _isNavigating = true;

    print(
      '🧭 Navigation started with ${route.instructions.length} instructions',
    );

    // Start listening to location updates
    _locationSubscription = _locationService.getLocationStream().listen(
      _onLocationUpdate,
      onError: (error) {
        print('❌ Location error: $error');
      },
    );

    // Announce first instruction
    if (route.instructions.isNotEmpty) {
      _announceInstruction(route.instructions[0], isFirst: true);
    }
  }

  // Stop navigation
  Future<void> stopNavigation() async {
    _isNavigating = false;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _currentRoute = null;
    _currentInstructionIndex = 0;
    _lastPosition = null;
    _lastValidPosition = null;
    print('🛑 Navigation stopped');
  }

  // Handle location updates
  void _onLocationUpdate(Position position) {
    if (!_isNavigating || _currentRoute == null) return;

    // Filter GPS noise
    final filteredPosition = _filterGPSNoise(position);
    if (filteredPosition == null) return;

    _lastPosition = filteredPosition;

    final currentLatLng = LatLng(position.latitude, position.longitude);

    // Check if still on route
    final isOnRoute = _isOnRoute(currentLatLng);

    // Calculate distances
    final distanceToNextTurn = _calculateDistanceToNextInstruction(
      currentLatLng,
    );
    final distanceRemaining = _calculateDistanceRemaining(currentLatLng);
    final timeRemaining = _calculateTimeRemaining(
      distanceRemaining,
      position.speed,
    );

    // Check if we've reached the next instruction
    _checkInstructionProximity(currentLatLng, distanceToNextTurn);

    // Check if arrived
    if (_checkArrival(currentLatLng)) {
      _handleArrival();
      return;
    }

    // Create navigation state
    final state = NavigationState(
      currentPosition: currentLatLng,
      currentInstructionIndex: _currentInstructionIndex,
      distanceToNextTurn: distanceToNextTurn,
      distanceRemaining: distanceRemaining,
      timeRemaining: timeRemaining,
      isOnRoute: isOnRoute,
      currentSpeed: position.speed * 3.6, // Convert m/s to km/h
      currentHeading: position.heading,
    );

    // Emit navigation state
    _navigationStateController.add(state);

    // Handle off-route
    if (!isOnRoute) {
      _handleOffRoute(currentLatLng);
    }
  }

  // Filter GPS noise
  Position? _filterGPSNoise(Position position) {
    // Only accept positions with good accuracy
    if (position.accuracy > accuracyThreshold) {
      print('⚠️ Low accuracy GPS: ${position.accuracy}m');
      return _lastValidPosition;
    }

    // Check if movement is reasonable (not teleporting)
    if (_lastValidPosition != null) {
      double distance = Geolocator.distanceBetween(
        _lastValidPosition!.latitude,
        _lastValidPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      double timeDiff = position.timestamp
          .difference(_lastValidPosition!.timestamp)
          .inSeconds
          .toDouble();
      if (timeDiff > 0) {
        double speed = distance / timeDiff; // m/s

        // Reject if speed is unrealistic (>150 km/h = 41.67 m/s)
        if (speed > 41.67) {
          print('⚠️ Unrealistic speed: ${speed * 3.6} km/h');
          return _lastValidPosition;
        }
      }
    }

    _lastValidPosition = position;
    return position;
  }

  // Check if on route
  bool _isOnRoute(LatLng currentPosition) {
    if (_currentRoute == null) return false;

    // Find minimum distance to route polyline
    double minDistance = double.infinity;

    for (int i = 0; i < _currentRoute!.coordinates.length - 1; i++) {
      final segmentStart = _currentRoute!.coordinates[i];
      final segmentEnd = _currentRoute!.coordinates[i + 1];

      final distance = _distanceToLineSegment(
        currentPosition,
        segmentStart,
        segmentEnd,
      );

      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance <= offRouteThreshold;
  }

  // Calculate distance to line segment
  double _distanceToLineSegment(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
    final distance = const Distance();

    // Calculate vectors
    final lineLength = distance.as(LengthUnit.Meter, lineStart, lineEnd);
    if (lineLength == 0) return distance.as(LengthUnit.Meter, point, lineStart);

    // Calculate projection
    final t =
        ((point.latitude - lineStart.latitude) *
                (lineEnd.latitude - lineStart.latitude) +
            (point.longitude - lineStart.longitude) *
                (lineEnd.longitude - lineStart.longitude)) /
        (lineLength * lineLength);

    if (t < 0) {
      return distance.as(LengthUnit.Meter, point, lineStart);
    } else if (t > 1) {
      return distance.as(LengthUnit.Meter, point, lineEnd);
    }

    // Project point onto line segment
    final projectedLat =
        lineStart.latitude + t * (lineEnd.latitude - lineStart.latitude);
    final projectedLon =
        lineStart.longitude + t * (lineEnd.longitude - lineStart.longitude);

    return distance.as(
      LengthUnit.Meter,
      point,
      LatLng(projectedLat, projectedLon),
    );
  }

  // Calculate distance to next instruction
  int _calculateDistanceToNextInstruction(LatLng currentPosition) {
    if (_currentRoute == null ||
        _currentInstructionIndex >= _currentRoute!.instructions.length) {
      return 0;
    }

    final nextInstruction =
        _currentRoute!.instructions[_currentInstructionIndex];
    if (nextInstruction.point == null) return 0;

    final distance = const Distance();
    return distance
        .as(LengthUnit.Meter, currentPosition, nextInstruction.point!)
        .round();
  }

  // Calculate total distance remaining
  int _calculateDistanceRemaining(LatLng currentPosition) {
    if (_currentRoute == null) return 0;

    // Find closest point on route
    int closestIndex = 0;
    double minDistance = double.infinity;
    final distance = const Distance();

    for (int i = 0; i < _currentRoute!.coordinates.length; i++) {
      final d = distance.as(
        LengthUnit.Meter,
        currentPosition,
        _currentRoute!.coordinates[i],
      );
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    // Calculate remaining distance from closest point
    double remainingDistance = 0;
    for (int i = closestIndex; i < _currentRoute!.coordinates.length - 1; i++) {
      remainingDistance += distance.as(
        LengthUnit.Meter,
        _currentRoute!.coordinates[i],
        _currentRoute!.coordinates[i + 1],
      );
    }

    return remainingDistance.round();
  }

  // Calculate time remaining
  int _calculateTimeRemaining(int distanceRemaining, double currentSpeed) {
    if (currentSpeed <= 0) {
      // Use original route time if not moving
      return _currentRoute?.travelTimeInSeconds ?? 0;
    }

    // Calculate time based on current speed
    // currentSpeed is in m/s
    return (distanceRemaining / currentSpeed).round();
  }

  // Check instruction proximity and advance
  void _checkInstructionProximity(LatLng currentPosition, int distance) {
    if (_currentRoute == null ||
        _currentInstructionIndex >= _currentRoute!.instructions.length) {
      return;
    }

    final currentInstruction =
        _currentRoute!.instructions[_currentInstructionIndex];

    // Announce at different distances
    if (distance <= 100 && distance > 50) {
      _voiceGuidanceController.add(
        'In 100 meters, ${currentInstruction.instruction}',
      );
    } else if (distance <= 500 && distance > 400) {
      _voiceGuidanceController.add(
        'In 500 meters, ${currentInstruction.instruction}',
      );
    }

    // Move to next instruction when close enough
    if (distance <= 30) {
      _currentInstructionIndex++;
      print(
        '✅ Instruction completed. Moving to ${_currentInstructionIndex + 1}/${_currentRoute!.instructions.length}',
      );

      if (_currentInstructionIndex < _currentRoute!.instructions.length) {
        _announceInstruction(
          _currentRoute!.instructions[_currentInstructionIndex],
        );
      }
    }
  }

  // Announce instruction
  void _announceInstruction(
    RouteInstruction instruction, {
    bool isFirst = false,
  }) {
    String message = instruction.instruction;
    if (isFirst) {
      message = 'Starting navigation. $message';
    }
    _voiceGuidanceController.add(message);
    print('🔊 $message');
  }

  // Check if arrived
  bool _checkArrival(LatLng currentPosition) {
    if (_currentRoute == null || _currentRoute!.coordinates.isEmpty)
      return false;

    final destination = _currentRoute!.coordinates.last;
    final distance = const Distance();
    final distanceToDestination = distance.as(
      LengthUnit.Meter,
      currentPosition,
      destination,
    );

    return distanceToDestination <= arrivalThreshold;
  }

  // Handle arrival
  void _handleArrival() {
    print('🎉 Arrived at destination!');
    _voiceGuidanceController.add('You have arrived at your destination');
    stopNavigation();
  }

  // Handle off-route
  void _handleOffRoute(LatLng currentPosition) {
    print('⚠️ Off route! Calculating new route...');
    _voiceGuidanceController.add('Recalculating route');

    // TODO: Trigger reroute from current position to destination
    // This will be called from the UI layer
  }

  // Get current navigation instruction
  RouteInstruction? getCurrentInstruction() {
    if (_currentRoute == null ||
        _currentInstructionIndex >= _currentRoute!.instructions.length) {
      return null;
    }
    return _currentRoute!.instructions[_currentInstructionIndex];
  }

  // Get next instruction (preview)
  RouteInstruction? getNextInstruction() {
    if (_currentRoute == null ||
        _currentInstructionIndex + 1 >= _currentRoute!.instructions.length) {
      return null;
    }
    return _currentRoute!.instructions[_currentInstructionIndex + 1];
  }

  // Dispose
  void dispose() {
    _navigationStateController.close();
    _voiceGuidanceController.close();
    _locationSubscription?.cancel();
  }
}
