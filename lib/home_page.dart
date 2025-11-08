import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/map_home_page.dart';
import 'config/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Check location permission after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermission();
    });
  }

  Future<void> _checkLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    
    if (!serviceEnabled) {
      // Location services are disabled, show dialog
      if (mounted) {
        _showLocationDialog();
      }
      return;
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      // Permission denied, show dialog
      if (mounted) {
        _showLocationDialog();
      }
    }
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true, // Can be dismissed
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2a2a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(
            Icons.location_off,
            color: AppTheme.primaryGreen,
            size: 48,
          ),
          title: const Text(
            'Location Access Required',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFFf5f6fa),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Traffinity needs location access to provide navigation, real-time traffic updates, and personalized route suggestions.\n\nPlease enable location services in your device settings.',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFF9e9e9e),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Later',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF9e9e9e),
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Open device settings
                await openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Open Settings',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF1c1c1c),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const MapHomePage();
  }
}
