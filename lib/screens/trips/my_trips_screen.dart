import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/trip_model.dart';
import '../../services/supabase_service.dart';
import '../../services/tomtom_service.dart';
import '../../models/location_model.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TomTomService _tomtomService = TomTomService();
  List<Trip> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    
    final tripsData = await _supabaseService.getUserTrips();
    
    setState(() {
      _trips = tripsData.map((data) => Trip.fromJson(data)).toList();
      _isLoading = false;
    });
  }

  Future<void> _showAddEditTripDialog({Trip? trip}) async {
    await showDialog(
      context: context,
      builder: (context) => _AddEditTripDialog(
        trip: trip,
        tomtomService: _tomtomService,
      ),
    );
    _loadTrips();
  }

  Future<void> _deleteTrip(Trip trip) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text(
          'Delete Trip',
          style: TextStyle(
            color: Color(0xFFf5f6fa),
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${trip.tripName}"?',
          style: const TextStyle(
            color: Color(0xFF9e9e9e),
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF9e9e9e),
                fontFamily: 'Poppins',
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf54748),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final success = await _supabaseService.deleteTrip(trip.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted successfully')),
        );
        _loadTrips();
      }
    }
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
          'My Trips',
          style: TextStyle(
            color: Color(0xFFf5f6fa),
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF06d6a0)),
            )
          : _trips.isEmpty
              ? _buildEmptyState()
              : _buildTripsList(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF06d6a0),
        onPressed: () => _showAddEditTripDialog(),
        child: const Icon(Icons.add, color: Color.fromARGB(255, 0, 0, 0)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.luggage_outlined,
            size: 80,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'No trips yet',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first trip',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        final trip = _trips[index];
        return _buildTripCard(trip);
      },
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAddEditTripDialog(trip: trip),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name and Transport Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06d6a0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getTransportIcon(trip.transportType),
                        color: const Color(0xFF06d6a0),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.tripName,
                            style: const TextStyle(
                              color: Color(0xFFf5f6fa),
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildStatusBadge(trip.status),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF9e9e9e),
                      ),
                      color: const Color(0xFF2a2a2a),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showAddEditTripDialog(trip: trip);
                        } else if (value == 'delete') {
                          _deleteTrip(trip);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Color(0xFF9e9e9e), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: Color(0xFFf5f6fa),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Color(0xFFf54748), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Color(0xFFf54748),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Route: Start -> End
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
                        trip.startLocationName,
                        style: const TextStyle(
                          color: Color(0xFF9e9e9e),
                          fontFamily: 'Poppins',
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 2,
                    height: 20,
                    color: const Color(0xFF3a3a3a),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.flag,
                      color: Color(0xFFf54748),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trip.endLocationName,
                        style: const TextStyle(
                          color: Color(0xFF9e9e9e),
                          fontFamily: 'Poppins',
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Info Row: Dates, Distance
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.calendar_today,
                      DateFormat('MMM d').format(trip.startDate),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: Color(0xFF9e9e9e), size: 16),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.calendar_today,
                      DateFormat('MMM d').format(trip.endDate),
                    ),
                    const Spacer(),
                    _buildInfoChip(
                      Icons.straighten,
                      trip.formattedDistance,
                    ),
                  ],
                ),
                
                // Description if available
                if (trip.description != null && trip.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    trip.description!,
                    style: const TextStyle(
                      color: Color(0xFF9e9e9e),
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'completed':
        color = const Color(0xFF06d6a0);
        break;
      case 'in_progress':
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        Trip(
          id: '',
          userId: '',
          tripName: '',
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          startLocationName: '',
          startLocationLat: 0,
          startLocationLon: 0,
          endLocationName: '',
          endLocationLat: 0,
          endLocationLon: 0,
          distanceKm: 0,
          transportType: '',
          status: status,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ).statusDisplay,
        style: TextStyle(
          color: color,
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3a3a3a),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF9e9e9e)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF9e9e9e),
              fontFamily: 'Poppins',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTransportIcon(String type) {
    switch (type) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
        return Icons.two_wheeler;
      case 'train':
        return Icons.train;
      case 'bus':
        return Icons.directions_bus;
      case 'plane':
        return Icons.flight;
      default:
        return Icons.directions;
    }
  }
}

// Add/Edit Trip Dialog
class _AddEditTripDialog extends StatefulWidget {
  final Trip? trip;
  final TomTomService tomtomService;

  const _AddEditTripDialog({
    this.trip,
    required this.tomtomService,
  });

  @override
  State<_AddEditTripDialog> createState() => _AddEditTripDialogState();
}

class _AddEditTripDialogState extends State<_AddEditTripDialog> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final _tripNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startLocationController = TextEditingController();
  final _endLocationController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _selectedTransport = 'car';
  String _selectedStatus = 'planned';
  
  SearchResult? _startLocation;
  SearchResult? _endLocation;
  List<SearchResult> _startSearchResults = [];
  List<SearchResult> _endSearchResults = [];
  bool _isSearchingStart = false;
  bool _isSearchingEnd = false;
  double? _calculatedDistance;
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    if (widget.trip != null) {
      _tripNameController.text = widget.trip!.tripName;
      _descriptionController.text = widget.trip!.description ?? '';
      _startDate = widget.trip!.startDate;
      _endDate = widget.trip!.endDate;
      _selectedTransport = widget.trip!.transportType;
      _selectedStatus = widget.trip!.status;
      
      _startLocation = SearchResult(
        name: widget.trip!.startLocationName,
        address: widget.trip!.startLocationName,
        latitude: widget.trip!.startLocationLat,
        longitude: widget.trip!.startLocationLon,
      );
      _endLocation = SearchResult(
        name: widget.trip!.endLocationName,
        address: widget.trip!.endLocationName,
        latitude: widget.trip!.endLocationLat,
        longitude: widget.trip!.endLocationLon,
      );
      _startLocationController.text = widget.trip!.startLocationName;
      _endLocationController.text = widget.trip!.endLocationName;
      _calculatedDistance = widget.trip!.distanceKm;
    }
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    _descriptionController.dispose();
    _startLocationController.dispose();
    _endLocationController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query, bool isStart) async {
    if (query.isEmpty) {
      setState(() {
        if (isStart) {
          _startSearchResults = [];
          _isSearchingStart = false;
        } else {
          _endSearchResults = [];
          _isSearchingEnd = false;
        }
      });
      return;
    }

    setState(() {
      if (isStart) {
        _isSearchingStart = true;
      } else {
        _isSearchingEnd = true;
      }
    });

    final results = await widget.tomtomService.searchLocations(query);

    if (mounted) {
      setState(() {
        if (isStart) {
          _startSearchResults = results;
          _isSearchingStart = false;
        } else {
          _endSearchResults = results;
          _isSearchingEnd = false;
        }
      });
    }
  }

  Future<void> _calculateDistance() async {
    if (_startLocation == null || _endLocation == null) return;

    setState(() => _isCalculating = true);

    final route = await widget.tomtomService.calculateRoute(
      startLat: _startLocation!.latitude,
      startLon: _startLocation!.longitude,
      endLat: _endLocation!.latitude,
      endLon: _endLocation!.longitude,
    );

    if (mounted) {
      setState(() {
        _calculatedDistance = route != null ? route.distanceInMeters / 1000 : null;
        _isCalculating = false;
      });
    }
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startLocation == null || _endLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end locations')),
      );
      return;
    }
    if (_calculatedDistance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculating distance...')),
      );
      await _calculateDistance();
      if (_calculatedDistance == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not calculate distance')),
        );
        return;
      }
    }

    bool success;
    if (widget.trip == null) {
      final result = await _supabaseService.addTrip(
        tripName: _tripNameController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        startDate: _startDate,
        endDate: _endDate,
        startLocationName: _startLocation!.name,
        startLocationLat: _startLocation!.latitude,
        startLocationLon: _startLocation!.longitude,
        endLocationName: _endLocation!.name,
        endLocationLat: _endLocation!.latitude,
        endLocationLon: _endLocation!.longitude,
        distanceKm: _calculatedDistance!,
        transportType: _selectedTransport,
        status: _selectedStatus,
      );
      success = result != null;
    } else {
      success = await _supabaseService.updateTrip(
        tripId: widget.trip!.id,
        tripName: _tripNameController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        startDate: _startDate,
        endDate: _endDate,
        startLocationName: _startLocation!.name,
        startLocationLat: _startLocation!.latitude,
        startLocationLon: _startLocation!.longitude,
        endLocationName: _endLocation!.name,
        endLocationLat: _endLocation!.latitude,
        endLocationLon: _endLocation!.longitude,
        distanceKm: _calculatedDistance!,
        transportType: _selectedTransport,
        status: _selectedStatus,
      );
    }

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.trip == null ? 'Trip added successfully' : 'Trip updated successfully',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save trip')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2a2a2a),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: MediaQuery.of(context).size.width - 40,
            height: MediaQuery.of(context).size.height - 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fixed Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.trip == null ? 'Add Trip' : 'Edit Trip',
                          style: const TextStyle(
                            color: Color(0xFFf5f6fa),
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF9e9e9e)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                  // Trip Name
                  TextFormField(
                    controller: _tripNameController,
                    style: const TextStyle(color: Color(0xFFf5f6fa), fontFamily: 'Poppins'),
                    decoration: InputDecoration(
                      labelText: 'Trip Name',
                      labelStyle: const TextStyle(color: Color(0xFF9e9e9e), fontFamily: 'Poppins'),
                      filled: true,
                      fillColor: const Color(0xFF1c1c1c),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a trip name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Color(0xFFf5f6fa), fontFamily: 'Poppins'),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      labelStyle: const TextStyle(color: Color(0xFF9e9e9e), fontFamily: 'Poppins'),
                      filled: true,
                      fillColor: const Color(0xFF1c1c1c),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start Location
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _startLocationController,
                        style: const TextStyle(color: Color(0xFFf5f6fa), fontFamily: 'Poppins'),
                        decoration: InputDecoration(
                          labelText: 'Start Location',
                          labelStyle: const TextStyle(color: Color(0xFF9e9e9e), fontFamily: 'Poppins'),
                          filled: true,
                          fillColor: const Color(0xFF1c1c1c),
                          prefixIcon: const Icon(Icons.location_on, color: Color(0xFF06d6a0)),
                          suffixIcon: _isSearchingStart
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF06d6a0),
                                    ),
                                  ),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) => _searchLocation(value, true),
                        validator: (value) {
                          if (_startLocation == null) {
                            return 'Please select a start location';
                          }
                          return null;
                        },
                      ),
                      if (_startSearchResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1c1c1c),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _startSearchResults.length,
                            itemBuilder: (context, index) {
                              final result = _startSearchResults[index];
                              return ListTile(
                                title: Text(
                                  result.name,
                                  style: const TextStyle(
                                    color: Color(0xFFf5f6fa),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  result.address,
                                  style: const TextStyle(
                                    color: Color(0xFF9e9e9e),
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    _startLocation = result;
                                    _startLocationController.text = result.name;
                                    _startSearchResults = [];
                                  });
                                  if (_endLocation != null) {
                                    _calculateDistance();
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // End Location
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _endLocationController,
                        style: const TextStyle(color: Color(0xFFf5f6fa), fontFamily: 'Poppins'),
                        decoration: InputDecoration(
                          labelText: 'End Location',
                          labelStyle: const TextStyle(color: Color(0xFF9e9e9e), fontFamily: 'Poppins'),
                          filled: true,
                          fillColor: const Color(0xFF1c1c1c),
                          prefixIcon: const Icon(Icons.flag, color: Color(0xFFf54748)),
                          suffixIcon: _isSearchingEnd
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF06d6a0),
                                    ),
                                  ),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) => _searchLocation(value, false),
                        validator: (value) {
                          if (_endLocation == null) {
                            return 'Please select an end location';
                          }
                          return null;
                        },
                      ),
                      if (_endSearchResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1c1c1c),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _endSearchResults.length,
                            itemBuilder: (context, index) {
                              final result = _endSearchResults[index];
                              return ListTile(
                                title: Text(
                                  result.name,
                                  style: const TextStyle(
                                    color: Color(0xFFf5f6fa),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  result.address,
                                  style: const TextStyle(
                                    color: Color(0xFF9e9e9e),
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    _endLocation = result;
                                    _endLocationController.text = result.name;
                                    _endSearchResults = [];
                                  });
                                  if (_startLocation != null) {
                                    _calculateDistance();
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Distance Display
                  if (_calculatedDistance != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06d6a0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF06d6a0), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.straighten, color: Color(0xFF06d6a0), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Distance: ${_calculatedDistance!.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: Color(0xFF06d6a0),
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isCalculating)
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF06d6a0),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Calculating distance...',
                            style: TextStyle(
                              color: Color(0xFF9e9e9e),
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Dates
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Start Date',
                              style: TextStyle(
                                color: Color(0xFF9e9e9e),
                                fontFamily: 'Poppins',
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
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
                                if (date != null) {
                                  setState(() {
                                    _startDate = date;
                                    if (_endDate.isBefore(_startDate)) {
                                      _endDate = _startDate;
                                    }
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1c1c1c),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, color: Color(0xFF9e9e9e), size: 18),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        DateFormat('MMM d, y').format(_startDate),
                                        style: const TextStyle(
                                          color: Color(0xFFf5f6fa),
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End Date',
                              style: TextStyle(
                                color: Color(0xFF9e9e9e),
                                fontFamily: 'Poppins',
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate,
                                  firstDate: _startDate,
                                  lastDate: DateTime(2030),
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
                                if (date != null) {
                                  setState(() => _endDate = date);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1c1c1c),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, color: Color(0xFF9e9e9e), size: 18),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        DateFormat('MMM d, y').format(_endDate),
                                        style: const TextStyle(
                                          color: Color(0xFFf5f6fa),
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                  const SizedBox(height: 16),

                  // Transport Type
                  const Text(
                    'Transport Type',
                    style: TextStyle(
                      color: Color(0xFF9e9e9e),
                      fontFamily: 'Poppins',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildTransportOption('car', Icons.directions_car),
                        const SizedBox(width: 8),
                        _buildTransportOption('bike', Icons.two_wheeler),
                        const SizedBox(width: 8),
                        _buildTransportOption('train', Icons.train),
                        const SizedBox(width: 8),
                        _buildTransportOption('bus', Icons.directions_bus),
                        const SizedBox(width: 8),
                        _buildTransportOption('plane', Icons.flight),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status
                  const Text(
                    'Status',
                    style: TextStyle(
                      color: Color(0xFF9e9e9e),
                      fontFamily: 'Poppins',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusOption('planned', 'Planned', Colors.blue),
                      const SizedBox(width: 8),
                      _buildStatusOption('in_progress', 'In Progress', Colors.orange),
                      const SizedBox(width: 8),
                      _buildStatusOption('completed', 'Completed', const Color(0xFF06d6a0)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        // Fixed Footer with Buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a2a),
            border: Border(
              top: BorderSide(color: const Color(0xFF3a3a3a), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF9e9e9e),
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06d6a0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _saveTrip,
                child: Text(
                  widget.trip == null ? 'Add Trip' : 'Update Trip',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildTransportOption(String type, IconData icon) {
    final isSelected = _selectedTransport == type;
    return InkWell(
      onTap: () => setState(() => _selectedTransport = type),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF06d6a0).withOpacity(0.2) : const Color(0xFF1c1c1c),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF06d6a0) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF06d6a0) : const Color(0xFF9e9e9e),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildStatusOption(String status, String label, Color color) {
    final isSelected = _selectedStatus == status;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedStatus = status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : const Color(0xFF1c1c1c),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? color : const Color(0xFF9e9e9e),
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
