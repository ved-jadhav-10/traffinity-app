import 'package:flutter/material.dart';
import '../../services/bus_service.dart';

class BusSearchScreen extends StatefulWidget {
  const BusSearchScreen({super.key});

  @override
  State<BusSearchScreen> createState() => _BusSearchScreenState();
}

class _BusSearchScreenState extends State<BusSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BusService _busService = BusService();

  // Stop to Stop search
  BusStop? _fromStop;
  BusStop? _toStop;
  List<BusRoute> _buses = [];
  bool _isSearchingBuses = false;

  // Route Number search
  final TextEditingController _routeNumberController = TextEditingController();
  BusRouteDetails? _routeDetails;
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _routeNumberController.dispose();
    super.dispose();
  }

  // Search stops dialog
  Future<BusStop?> _showStopSearchDialog(String title) async {
    return showDialog<BusStop>(
      context: context,
      builder: (context) =>
          _StopSearchDialog(title: title, busService: _busService),
    );
  }

  // Search buses between stops
  Future<void> _searchBuses() async {
    print('🔍 Bus search button clicked');
    print('From: ${_fromStop?.name} (${_fromStop?.code})');
    print('To: ${_toStop?.name} (${_toStop?.code})');

    if (_fromStop == null || _toStop == null) {
      print('❌ Missing stop selection');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both stops'),
          backgroundColor: Color(0xFFf54748),
        ),
      );
      return;
    }

    print('✅ Starting bus search...');
    setState(() => _isSearchingBuses = true);

    try {
      final buses = await _busService.searchBusRoutes(
        fromLocation: _fromStop!.name,
        toLocation: _toStop!.name,
      );

      print('✅ Found ${buses.length} buses');
      setState(() {
        _buses = buses;
        _isSearchingBuses = false;
      });
    } catch (e) {
      print('❌ Error searching buses: $e');
      setState(() => _isSearchingBuses = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFf54748),
          ),
        );
      }
    }
  }

  // Search route by number
  Future<void> _searchRouteByNumber() async {
    final routeNumber = _routeNumberController.text.trim();
    print('🔍 Searching for route: $routeNumber');

    if (routeNumber.isEmpty) {
      print('❌ Empty route number');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a route number'),
          backgroundColor: Color(0xFFf54748),
        ),
      );
      return;
    }

    print('✅ Starting route search...');
    setState(() => _isLoadingRoute = true);

    try {
      final details = await _busService.getBusRouteDetails(routeNumber);

      print('✅ Route loaded: ${details?.routeName ?? "Not found"}');
      setState(() {
        _routeDetails = details;
        _isLoadingRoute = false;
      });

      if (details == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route not found'),
            backgroundColor: Color(0xFFf54748),
          ),
        );
      }
    } catch (e) {
      print('❌ Error loading route: $e');
      setState(() => _isLoadingRoute = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFf54748),
          ),
        );
      }
    }
  }

  // Swap stops
  void _swapStops() {
    setState(() {
      final temp = _fromStop;
      _fromStop = _toStop;
      _toStop = temp;
    });
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
          'Bus Search',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFf5f6fa),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF06d6a0),
          labelColor: const Color(0xFF06d6a0),
          unselectedLabelColor: const Color(0xFF9e9e9e),
          labelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Stop to Stop'),
            Tab(text: 'Route Number'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildStopToStopTab(), _buildRouteNumberTab()],
      ),
    );
  }

  // Build Stop to Stop tab
  Widget _buildStopToStopTab() {
    return Container(
      color: const Color(0xFF1c1c1c),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // From Stop
            _buildStopSelector(
              label: 'From',
              stop: _fromStop,
              onTap: () async {
                final stop = await _showStopSearchDialog(
                  'Select Starting Stop',
                );
                if (stop != null) {
                  setState(() => _fromStop = stop);
                }
              },
            ),
            const SizedBox(height: 16),

            // Swap Button
            Center(
              child: IconButton(
                onPressed: _swapStops,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2a2a),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF3a3a3a)),
                  ),
                  child: const Icon(
                    Icons.swap_vert,
                    color: Color(0xFF06d6a0),
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // To Stop
            _buildStopSelector(
              label: 'To',
              stop: _toStop,
              onTap: () async {
                final stop = await _showStopSearchDialog(
                  'Select Destination Stop',
                );
                if (stop != null) {
                  setState(() => _toStop = stop);
                }
              },
            ),
            const SizedBox(height: 24),

            // Search Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSearchingBuses ? null : _searchBuses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06d6a0),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSearchingBuses
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Search Buses',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Bus Results
            if (_buses.isNotEmpty) ...[
              const Text(
                'Available Buses',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFf5f6fa),
                ),
              ),
              const SizedBox(height: 12),
              ..._buses.map((bus) => _buildBusCard(bus)),
            ] else if (!_isSearchingBuses &&
                _fromStop != null &&
                _toStop != null) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.directions_bus,
                        size: 64,
                        color: const Color(0xFF9e9e9e).withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No buses found',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Color(0xFF9e9e9e),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Build Route Number tab
  Widget _buildRouteNumberTab() {
    return Container(
      color: const Color(0xFF1c1c1c),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Route Number',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 12),

            // Route Number Input
            TextField(
              controller: _routeNumberController,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Color(0xFFf5f6fa),
              ),
              decoration: InputDecoration(
                hintText: 'e.g. AS-1, 764, G-4',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF7a7a7a),
                ),
                filled: true,
                fillColor: const Color(0xFF2a2a2a),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),

            // Search Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoadingRoute ? null : _searchRouteByNumber,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06d6a0),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoadingRoute
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Get Route Details',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Route Details Results
            if (_routeDetails != null) ...[
              _buildRouteDetailsCard(_routeDetails!),
            ],
          ],
        ),
      ),
    );
  }

  // Stop Selector Widget
  Widget _buildStopSelector({
    required String label,
    required BusStop? stop,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: stop != null
                ? const Color(0xFF06d6a0)
                : const Color(0xFF3a3a3a),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF06d6a0).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFF06d6a0),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFF9e9e9e),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stop?.name ?? 'Select stop',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: stop != null
                          ? const Color(0xFFf5f6fa)
                          : const Color(0xFF7a7a7a),
                    ),
                  ),
                  if (stop != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${stop.code} • ${stop.city}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFF9e9e9e),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF9e9e9e),
            ),
          ],
        ),
      ),
    );
  }

  // Bus Card Widget
  Widget _buildBusCard(BusRoute bus) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3a3a3a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Number and Type
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF06d6a0).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bus.routeNumber,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF06d6a0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getBusTypeColor(bus.busType).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  bus.busType,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getBusTypeColor(bus.busType),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                bus.operator,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9e9e9e),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bus Name
          Text(
            bus.busName,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFFf5f6fa),
            ),
          ),
          const SizedBox(height: 12),

          // Timing and Duration
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Color(0xFF9e9e9e)),
              const SizedBox(width: 6),
              Text(
                bus.departureTime,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFFf5f6fa),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.schedule, size: 16, color: Color(0xFF9e9e9e)),
              const SizedBox(width: 6),
              Text(
                bus.estimatedDuration,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFFf5f6fa),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF3a3a3a), height: 1),
          const SizedBox(height: 12),

          // Fare, Frequency, and Occupancy
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip(
                Icons.currency_rupee,
                bus.fare,
                const Color(0xFF06d6a0),
              ),
              _buildInfoChip(
                Icons.repeat,
                bus.frequency,
                const Color(0xFFffa726),
              ),
              _buildOccupancyChip(bus.occupancy),
            ],
          ),
        ],
      ),
    );
  }

  // Route Details Card
  Widget _buildRouteDetailsCard(BusRouteDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a2a),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3a3a3a)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06d6a0).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      details.routeNumber,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF06d6a0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFffa726).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      details.busType,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFffa726),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    details.operator,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9e9e9e),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                details.routeName,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFf5f6fa),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF3a3a3a), height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDetailItem('First Bus', details.firstBus),
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFF3a3a3a),
                  ),
                  _buildDetailItem('Last Bus', details.lastBus),
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFF3a3a3a),
                  ),
                  _buildDetailItem('Frequency', details.frequency),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Stops Section
        const Text(
          'Route Stops',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFFf5f6fa),
          ),
        ),
        const SizedBox(height: 12),

        // Stops List
        ...details.stops.map((stop) => _buildStopCard(stop)),
      ],
    );
  }

  // Stop Card for route details
  Widget _buildStopCard(BusStopInfo stop) {
    final isFirst = stop.stopNumber == 1;
    final isLast = stop.stopNumber == 7 || stop.arrivalTime == '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Timeline
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isFirst || isLast
                        ? const Color(0xFF06d6a0)
                        : const Color(0xFF2a2a2a),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF06d6a0),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 50,
                    color: const Color(0xFF3a3a3a),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Stop Info
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2a2a2a),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3a3a3a)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.stopName,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFf5f6fa),
                          ),
                        ),
                        if (stop.arrivalTime != '--') ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 12,
                                color: Color(0xFF06d6a0),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                stop.arrivalTime,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Color(0xFF06d6a0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3a3a3a),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Stop ${stop.stopNumber}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Color(0xFF9e9e9e),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Color(0xFF9e9e9e),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFFf5f6fa),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildOccupancyChip(String occupancy) {
    Color color;
    switch (occupancy.toLowerCase()) {
      case 'low':
        color = const Color(0xFF06d6a0);
        break;
      case 'high':
      case 'very high':
        color = const Color(0xFFf54748);
        break;
      default:
        color = const Color(0xFFffa726);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.people, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          occupancy,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getBusTypeColor(String busType) {
    if (busType.contains('AC')) return const Color(0xFF2196F3);
    if (busType.contains('Volvo')) return const Color(0xFF9C27B0);
    if (busType.contains('Rainbow')) return const Color(0xFFFF5722);
    return const Color(0xFFffa726);
  }
}

// Stop Search Dialog
class _StopSearchDialog extends StatefulWidget {
  final String title;
  final BusService busService;

  const _StopSearchDialog({required this.title, required this.busService});

  @override
  State<_StopSearchDialog> createState() => _StopSearchDialogState();
}

class _StopSearchDialogState extends State<_StopSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<BusStop> _stops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStops() async {
    setState(() => _isLoading = true);
    try {
      final stops = await widget.busService.searchBusStops('');
      setState(() {
        _stops = stops;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchStops(String query) async {
    try {
      final stops = await widget.busService.searchBusStops(query);
      setState(() => _stops = stops);
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1c1c1c),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFf5f6fa),
              ),
              decoration: InputDecoration(
                hintText: 'Search stop name or code...',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF7a7a7a),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9e9e9e)),
                filled: true,
                fillColor: const Color(0xFF2a2a2a),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _searchStops,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF06d6a0),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _stops.length,
                      itemBuilder: (context, index) {
                        final stop = _stops[index];
                        return ListTile(
                          onTap: () => Navigator.pop(context, stop),
                          title: Text(
                            stop.name,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFf5f6fa),
                            ),
                          ),
                          subtitle: Text(
                            '${stop.code} • ${stop.city}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF9e9e9e),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Color(0xFF9e9e9e),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
