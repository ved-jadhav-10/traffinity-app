import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../models/civic_issue_model.dart';
import '../config/tomtom_config.dart';

class CivicIssueMapScreen extends StatefulWidget {
  const CivicIssueMapScreen({super.key});

  @override
  State<CivicIssueMapScreen> createState() => _CivicIssueMapScreenState();
}

class _CivicIssueMapScreenState extends State<CivicIssueMapScreen> {
  final MapController _mapController = MapController();
  final SupabaseService _supabaseService = SupabaseService();
  final LocationService _locationService = LocationService();

  LatLng? _currentLocation;
  List<CivicIssue> _issues = [];
  List<Marker> _issueMarkers = [];
  Timer? _refreshTimer;
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _compassHeading = 0.0;
  bool _isLoading = true;
  bool _isMapInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _startAutoRefresh();
    _setupCompass();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }

  void _setupCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (mounted && event.heading != null) {
        setState(() {
          _compassHeading = event.heading!;
        });
      }
    });
  }

  void _resetMapRotation() {
    _mapController.rotate(0);
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, _mapController.camera.zoom);
    }
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);

    // Get current location
    bool hasPermission = await _locationService.checkAndRequestPermissions();
    if (hasPermission) {
      Position? position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isMapInitialized = true;
        });

        // Load civic issues
        await _loadCivicIssues();
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadCivicIssues() async {
    if (_currentLocation == null) return;

    try {
      final issuesData = await _supabaseService.getCivicIssuesWithinRadius(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        radiusMeters: 25000, // 25km radius
      );

      if (mounted) {
        setState(() {
          _issues = issuesData.map((json) => CivicIssue.fromJson(json)).toList();
          _buildIssueMarkers();
        });
      }
    } catch (e) {
      print('Error loading civic issues: $e');
    }
  }

  void _buildIssueMarkers() {
    _issueMarkers = _issues.map((issue) {
      return Marker(
        point: LatLng(issue.latitude, issue.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showIssueDetails(issue),
          child: Image.asset(
            issue.iconAsset,
            width: 40,
            height: 40,
          ),
        ),
      );
    }).toList();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadCivicIssues();
      }
    });
  }

  void _showIssueDetails(CivicIssue issue) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2a2a2a),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF9e9e9e),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Badge: Civic Issue
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF06d6a0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Civic Issue',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Issue type with icon
            Row(
              children: [
                Image.asset(issue.iconAsset, width: 48, height: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    issue.issueTypeDisplay,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFf5f6fa),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Time information
            _buildInfoRow(Icons.access_time, 'Reported', issue.timeAgo),
            
            if (issue.distanceMeters != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.location_on, 'Distance', issue.formattedDistance),
            ],

            // Description if available
            if (issue.description != null && issue.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF444444)),
              const SizedBox(height: 12),
              const Text(
                'Description',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9e9e9e),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                issue.description!,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Color(0xFFf5f6fa),
                ),
              ),
            ],

            // Photo if available
            if (issue.photoUrl != null && issue.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF444444)),
              const SizedBox(height: 12),
              const Text(
                'Photo',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9e9e9e),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  issue.photoUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: const Color(0xFF1c1c1c),
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Color(0xFF9e9e9e),
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06d6a0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF06d6a0), size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Color(0xFF9e9e9e),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFf5f6fa),
            ),
          ),
        ),
      ],
    );
  }

  void _showReportIssueSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportIssueSheet(
        currentLocation: _currentLocation!,
        onIssueReported: () {
          _loadCivicIssues(); // Refresh issues after reporting
        },
      ),
    );
  }

  void _showReportIssueAtLocation(LatLng location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportIssueSheet(
        currentLocation: location,
        onIssueReported: () {
          _loadCivicIssues();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1c1c1c),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFf5f6fa)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Civic Issue Map',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFf5f6fa),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF06d6a0)),
            onPressed: _loadCivicIssues,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF06d6a0)),
            )
          : _isMapInitialized && _currentLocation != null
          ? Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation!,
                    initialZoom: 13.0,
                    minZoom: 10.0,
                    maxZoom: 18.0,
                    onLongPress: (tapPosition, point) {
                      // Allow reporting issue at tapped location
                      _showReportIssueAtLocation(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://api.tomtom.com/map/1/tile/basic/night/'
                          '{z}/{x}/{y}.png?key=${TomTomConfig.apiKey}',
                      userAgentPackageName: 'com.example.traffinity',
                    ),
                    // Current location marker
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation!,
                          width: 30,
                          height: 30,
                          child: const Icon(
                            Icons.my_location,
                            color: Color(0xFF06d6a0),
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                    // Issue markers
                    MarkerLayer(markers: _issueMarkers),
                  ],
                ),

                // Info card showing issue count
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2a2a2a).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_issues.length} civic issue${_issues.length != 1 ? 's' : ''} reported',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFf5f6fa),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Help make your city better',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF9e9e9e),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Info note for long press
                Positioned(
                  top: 100,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a2a2a).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Color(0xFF06d6a0),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Long press on the map to report an issue',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF9e9e9e),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Compass button for recentering
                Positioned(
                  right: 16,
                  bottom: 100,
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
                      onPressed: _resetMapRotation,
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
              ],
            )
          : const Center(
              child: Text(
                'Unable to get your location',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Color(0xFF9e9e9e),
                ),
              ),
            ),
      floatingActionButton: _isMapInitialized
          ? FloatingActionButton.extended(
              onPressed: _showReportIssueSheet,
              backgroundColor: const Color(0xFF06d6a0),
              icon: const Icon(Icons.report, color: Colors.black),
              label: const Text(
                'Report Issue',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            )
          : null,
    );
  }
}

// Report Issue Bottom Sheet
class ReportIssueSheet extends StatefulWidget {
  final LatLng currentLocation;
  final VoidCallback onIssueReported;

  const ReportIssueSheet({
    super.key,
    required this.currentLocation,
    required this.onIssueReported,
  });

  @override
  State<ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<ReportIssueSheet> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedType = 'water_shortage';
  String? _photoPath;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _issueTypes = [
    {
      'value': 'water_shortage',
      'label': 'Water Issue',
      'icon': Icons.water_drop,
    },
    {
      'value': 'garbage_disposal',
      'label': 'Garbage',
      'icon': Icons.delete,
    },
    {
      'value': 'air_pollution',
      'label': 'Air Pollution',
      'icon': Icons.air,
    },
    {
      'value': 'drainage_issue',
      'label': 'Drainage',
      'icon': Icons.water_damage,
    },
    {
      'value': 'road_damage',
      'label': 'Pothole',
      'icon': Icons.construction,
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _photoPath = image.path;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      // Upload photo to Supabase storage if _photoPath is not null
      String? photoUrl;
      
      if (_photoPath != null) {
        try {
          photoUrl = await _supabaseService.uploadCivicIssuePhoto(_photoPath!);
          
          if (photoUrl == null) {
            throw Exception('Upload returned null');
          }
        } catch (uploadError) {
          // Show specific error for photo upload
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Photo upload failed: ${uploadError.toString()}\n\n'
                  'Make sure the "civic-photos" bucket exists in Supabase Storage and is set to Public.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          throw Exception('Failed to upload photo. Please try again or submit without photo.');
        }
      }

      await _supabaseService.reportCivicIssue(
        issueType: _selectedType,
        latitude: widget.currentLocation.latitude,
        longitude: widget.currentLocation.longitude,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        photoUrl: photoUrl,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onIssueReported();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              photoUrl != null 
                ? 'Issue reported successfully with photo!'
                : 'Issue reported successfully!',
            ),
            backgroundColor: const Color(0xFF06d6a0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2a2a2a),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF9e9e9e),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Report Civic Issue',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 20),

            // Issue Type
            const Text(
              'Issue Type',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9e9e9e),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _issueTypes.map((type) {
                final isSelected = _selectedType == type['value'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type['value']),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 64) / 3,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF06d6a0)
                          : const Color(0xFF1c1c1c),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF06d6a0)
                            : const Color(0xFF444444),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          type['icon'],
                          size: 32,
                          color: isSelected ? Colors.black : const Color(0xFF9e9e9e),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          type['label'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: isSelected
                                ? Colors.black
                                : const Color(0xFFf5f6fa),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Description
            const Text(
              'Description (Optional)',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9e9e9e),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFFf5f6fa),
              ),
              decoration: InputDecoration(
                hintText: 'Add any additional details...',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Color(0xFF9e9e9e),
                ),
                filled: true,
                fillColor: const Color(0xFF1c1c1c),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Photo Upload
            const Text(
              'Photo (Optional)',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9e9e9e),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1c1c1c),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF444444),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _photoPath == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            color: Color(0xFF9e9e9e),
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap to add photo',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF9e9e9e),
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_photoPath!),
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _photoPath = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06d6a0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Report Issue',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
