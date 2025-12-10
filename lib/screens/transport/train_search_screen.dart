import 'package:flutter/material.dart';
import '../../services/indian_railways_service.dart';

class TrainSearchScreen extends StatefulWidget {
  const TrainSearchScreen({super.key});

  @override
  State<TrainSearchScreen> createState() => _TrainSearchScreenState();
}

class _TrainSearchScreenState extends State<TrainSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final IndianRailwaysService _railwaysService = IndianRailwaysService();

  // Station to Station search
  Station? _fromStation;
  Station? _toStation;
  List<TrainBetweenStations> _trains = [];
  bool _isSearchingTrains = false;

  // PNR Status search
  final TextEditingController _pnrController = TextEditingController();
  PNRStatus? _pnrStatus;
  bool _isLoadingPNR = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pnrController.dispose();
    super.dispose();
  }

  // Search stations dialog
  Future<Station?> _showStationSearchDialog(String title) async {
    return showDialog<Station>(
      context: context,
      builder: (context) =>
          _StationSearchDialog(title: title, railwaysService: _railwaysService),
    );
  }

  // Search trains between stations
  Future<void> _searchTrains() async {
    print('🔍 Search button clicked');
    print('From: ${_fromStation?.name} (${_fromStation?.code})');
    print('To: ${_toStation?.name} (${_toStation?.code})');

    if (_fromStation == null || _toStation == null) {
      print('❌ Missing station selection');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both stations'),
          backgroundColor: Color(0xFFf54748),
        ),
      );
      return;
    }

    print('✅ Starting train search...');
    setState(() => _isSearchingTrains = true);

    try {
      final trains = await _railwaysService.searchTrainsBetweenStations(
        fromStationCode: _fromStation!.code,
        toStationCode: _toStation!.code,
      );

      print('✅ Found ${trains.length} trains');
      setState(() {
        _trains = trains;
        _isSearchingTrains = false;
      });
    } catch (e) {
      print('❌ Error searching trains: $e');
      setState(() => _isSearchingTrains = false);
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

  // Search PNR status
  Future<void> _searchPNRStatus() async {
    final pnrNumber = _pnrController.text.trim();
    print('🔍 Searching for PNR: $pnrNumber');

    if (pnrNumber.isEmpty) {
      print('❌ Empty PNR number');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a PNR number'),
          backgroundColor: Color(0xFFf54748),
        ),
      );
      return;
    }

    if (pnrNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PNR number must be 10 digits'),
          backgroundColor: Color(0xFFf54748),
        ),
      );
      return;
    }

    print('✅ Starting PNR status search...');
    setState(() => _isLoadingPNR = true);

    try {
      final status = await _railwaysService.getPNRStatus(pnrNumber);

      print('✅ PNR status loaded: ${status?.trainName ?? "Not found"}');
      setState(() {
        _pnrStatus = status;
        _isLoadingPNR = false;
      });

      if (status == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PNR not found'),
            backgroundColor: Color(0xFFf54748),
          ),
        );
      }
    } catch (e) {
      print('❌ Error loading PNR status: $e');
      setState(() => _isLoadingPNR = false);
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

  // Swap stations
  void _swapStations() {
    setState(() {
      final temp = _fromStation;
      _fromStation = _toStation;
      _toStation = temp;
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
          'Train Search',
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
            Tab(text: 'Station to Station'),
            Tab(text: 'PNR Status'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildStationToStationTab(), _buildPNRStatusTab()],
      ),
    );
  }

  // Station to Station Tab
  Widget _buildStationToStationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // From Station
          _buildStationSelector(
            label: 'From',
            station: _fromStation,
            onTap: () async {
              final station = await _showStationSearchDialog(
                'Select Source Station',
              );
              if (station != null) {
                setState(() => _fromStation = station);
              }
            },
          ),
          const SizedBox(height: 12),

          // Swap Button
          Center(
            child: IconButton(
              onPressed: _swapStations,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2a2a),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.swap_vert, color: Color(0xFF06d6a0)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // To Station
          _buildStationSelector(
            label: 'To',
            station: _toStation,
            onTap: () async {
              final station = await _showStationSearchDialog(
                'Select Destination Station',
              );
              if (station != null) {
                setState(() => _toStation = station);
              }
            },
          ),
          const SizedBox(height: 24),

          // Search Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSearchingTrains ? null : _searchTrains,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06d6a0),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSearchingTrains
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Search Trains',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Results
          if (_trains.isNotEmpty) ...[
            const Text(
              'Available Trains',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 16),
            ..._trains.map((train) => _buildTrainCard(train)),
          ],
        ],
      ),
    );
  }

  // PNR Status Tab
  Widget _buildPNRStatusTab() {
    return Container(
      color: const Color(0xFF1c1c1c),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter PNR Number',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 12),

            // PNR Number Input
            TextField(
              controller: _pnrController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Color(0xFFf5f6fa),
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 2143794260',
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
                counterStyle: const TextStyle(color: Color(0xFF7a7a7a)),
              ),
            ),
            const SizedBox(height: 20),

            // Check PNR Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoadingPNR ? null : _searchPNRStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06d6a0),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoadingPNR
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
                        'Check PNR Status',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // PNR Status Results
            if (_pnrStatus != null) ...[
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
                    // PNR Number
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PNR Number',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF9e9e9e),
                          ),
                        ),
                        Text(
                          _pnrStatus!.pnrNumber,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF06d6a0),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF3a3a3a), height: 24),

                    // Train Details
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06d6a0).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _pnrStatus!.trainNumber,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF06d6a0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pnrStatus!.trainName,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFf5f6fa),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Journey Date
                    _buildInfoRow('Date of Journey', _pnrStatus!.dateOfJourney),
                    const SizedBox(height: 12),

                    // Boarding Station
                    _buildInfoRow(
                      'Boarding Station',
                      _pnrStatus!.boardingStation,
                    ),
                    const SizedBox(height: 12),

                    // Destination Station
                    _buildInfoRow(
                      'Destination',
                      _pnrStatus!.destinationStation,
                    ),
                    const SizedBox(height: 12),

                    // Chart Status
                    _buildInfoRow('Chart Status', _pnrStatus!.chartStatus),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Passengers Section
              const Text(
                'Passenger Details',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFf5f6fa),
                ),
              ),
              const SizedBox(height: 12),

              ..._pnrStatus!.passengers.map(
                (passenger) => Container(
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
                      Text(
                        'Passenger ${passenger.passengerNumber}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFf5f6fa),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Booking Status', passenger.bookingStatus),
                      const SizedBox(height: 8),
                      _buildInfoRow('Current Status', passenger.currentStatus),
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Color(0xFF9e9e9e),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
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

  // Station Selector Widget
  Widget _buildStationSelector({
    required String label,
    required Station? station,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3a3a3a), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF06d6a0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.train,
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
                    station != null
                        ? '${station.name} (${station.code})'
                        : 'Select Station',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: station != null
                          ? const Color(0xFFf5f6fa)
                          : const Color(0xFF7a7a7a),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF9e9e9e),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Train Card Widget
  Widget _buildTrainCard(TrainBetweenStations train) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06d6a0).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            train.trainNumber,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF06d6a0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFffa726).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            train.trainType,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFffa726),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      train.trainName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFf5f6fa),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Departs',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      train.departureTime,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF06d6a0),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    train.duration,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFF9e9e9e),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 60,
                    height: 2,
                    color: const Color(0xFF3a3a3a),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Arrives',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      train.arrivalTime,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFf54748),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Runs: ${train.runDays}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Color(0xFF9e9e9e),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Station Schedule Card
  Widget _buildStationScheduleCard(StationSchedule station) {
    final isSource = station.arrivalTime == 'Source';
    final isDestination = station.departureTime == 'Destination';

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
                    color: isSource || isDestination
                        ? const Color(0xFF06d6a0)
                        : const Color(0xFF3a3a3a),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF06d6a0),
                      width: 2,
                    ),
                  ),
                ),
                if (!isDestination)
                  Container(
                    width: 2,
                    height: 50,
                    color: const Color(0xFF3a3a3a),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Station Info
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2a2a2a),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3a3a3a)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          station.stationName,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFf5f6fa),
                          ),
                        ),
                      ),
                      Text(
                        station.stationCode,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF9e9e9e),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (!isSource) ...[
                        const Icon(
                          Icons.arrow_downward,
                          size: 12,
                          color: Color(0xFF06d6a0),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          station.arrivalTime,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Color(0xFF06d6a0),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (!isDestination) ...[
                        const Icon(
                          Icons.arrow_upward,
                          size: 12,
                          color: Color(0xFFf54748),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          station.departureTime,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Color(0xFFf54748),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        'Day ${station.day}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Color(0xFF9e9e9e),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Station Search Dialog
class _StationSearchDialog extends StatefulWidget {
  final String title;
  final IndianRailwaysService railwaysService;

  const _StationSearchDialog({
    required this.title,
    required this.railwaysService,
  });

  @override
  State<_StationSearchDialog> createState() => _StationSearchDialogState();
}

class _StationSearchDialogState extends State<_StationSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Station> _stations = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadStations('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStations(String query) async {
    setState(() => _isSearching = true);
    try {
      final stations = await widget.railwaysService.searchStations(query);
      setState(() {
        _stations = stations;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2a2a2a),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              onChanged: _loadStations,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFFf5f6fa),
              ),
              decoration: InputDecoration(
                hintText: 'Search station...',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF7a7a7a),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF06d6a0)),
                filled: true,
                fillColor: const Color(0xFF1c1c1c),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF06d6a0),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _stations.length,
                      itemBuilder: (context, index) {
                        final station = _stations[index];
                        return ListTile(
                          onTap: () => Navigator.pop(context, station),
                          leading: const Icon(
                            Icons.location_on,
                            color: Color(0xFF06d6a0),
                          ),
                          title: Text(
                            station.name,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFf5f6fa),
                            ),
                          ),
                          subtitle: Text(
                            '${station.code} - ${station.city}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF9e9e9e),
                            ),
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
