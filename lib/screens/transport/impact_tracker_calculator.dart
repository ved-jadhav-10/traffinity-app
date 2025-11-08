import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';

class ImpactTrackerCalculator extends StatefulWidget {
  const ImpactTrackerCalculator({super.key});

  @override
  State<ImpactTrackerCalculator> createState() =>
      _ImpactTrackerCalculatorState();
}

class _ImpactTrackerCalculatorState extends State<ImpactTrackerCalculator>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();

  // Controllers
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _tripsController = TextEditingController();

  // User selections
  String _usualMode = 'Car';
  String _alternateMode = 'Train';
  String _fuelType = 'Petrol';

  // Calculated values
  double _co2SavedPerMonth = 0.0;
  double _fuelSavedPerMonth = 0.0;
  double _moneySavedPerMonth = 0.0;
  String _ecoLevel = 'Eco Beginner';
  Color _ecoLevelColor = const Color(0xFF9e9e9e);

  // Control visibility
  bool _showStats = false;

  // User profile vehicle
  String? _userVehicleType;
  String? _userVehicleFuel;
  bool _isLoadingProfile = true;

  // Animation controller
  late AnimationController _animationController;

  // Emission factors (kg CO₂ per km)
  final Map<String, double> _emissionFactors = {
    'Car-Petrol': 0.192,
    'Car-Diesel': 0.171,
    'Car-Electric': 0.053,
    'Bike-Petrol': 0.084,
    'Bike-Diesel': 0.080,
    'Bike-Electric': 0.022,
    'Bus': 0.089,
    'Train': 0.041,
    'Metro': 0.035,
  };

  // Fuel prices (₹ per litre)
  final Map<String, double> _fuelPrices = {
    'Petrol': 106.0,
    'Diesel': 92.0,
    'Electric': 8.0, // ₹ per kWh
  };

  // CO₂ to fuel conversion (kg CO₂ per litre)
  final Map<String, double> _co2ToFuel = {
    'Petrol': 2.31,
    'Diesel': 2.68,
    'Electric': 0.82, // per kWh
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadUserProfile();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _tripsController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoadingProfile = true);

    try {
      final profile = await _supabaseService.getUserProfile();
      final vehiclesJson = profile['vehicles'] as List<dynamic>?;

      if (vehiclesJson != null && vehiclesJson.isNotEmpty) {
        final firstVehicle = vehiclesJson[0];
        setState(() {
          _userVehicleType = firstVehicle['type'] ?? 'car';
          _userVehicleFuel = firstVehicle['fuel'] ?? 'petrol';

          // Set usual mode based on user's vehicle
          if (_userVehicleType == 'car') {
            _usualMode = 'Car';
          } else if (_userVehicleType == 'bike') {
            _usualMode = 'Bike';
          }

          // Set fuel type
          if (_userVehicleFuel == 'petrol') {
            _fuelType = 'Petrol';
          } else if (_userVehicleFuel == 'diesel') {
            _fuelType = 'Diesel';
          } else if (_userVehicleFuel == 'electric') {
            _fuelType = 'Electric';
          }

          _isLoadingProfile = false;
        });
      } else {
        setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() => _isLoadingProfile = false);
    }
  }

  void _calculateImpact() {
    final distance = double.tryParse(_distanceController.text) ?? 0;
    final trips = double.tryParse(_tripsController.text) ?? 0;

    if (distance <= 0 || trips <= 0) {
      setState(() {
        _co2SavedPerMonth = 0.0;
        _fuelSavedPerMonth = 0.0;
        _moneySavedPerMonth = 0.0;
        _ecoLevel = 'Eco Beginner';
        _ecoLevelColor = const Color(0xFF9e9e9e);
      });
      return;
    }

    // Get emission factors
    final usualKey = '$_usualMode-$_fuelType';
    final alternateKey = _alternateMode;

    final usualEmission = _emissionFactors[usualKey] ?? 0.192;
    final alternateEmission = _emissionFactors[alternateKey] ?? 0.041;

    // Calculate CO₂ saved per trip
    final co2SavedPerTrip = (usualEmission - alternateEmission) * distance;

    // Calculate monthly savings (trips per week × 4)
    final co2SavedPerMonth = co2SavedPerTrip * trips * 4;

    // Calculate fuel saved
    final co2ToFuelFactor = _co2ToFuel[_fuelType] ?? 2.31;
    final fuelSavedPerMonth = co2SavedPerMonth / co2ToFuelFactor;

    // Calculate money saved
    final fuelPrice = _fuelPrices[_fuelType] ?? 106.0;
    final moneySavedPerMonth = fuelSavedPerMonth * fuelPrice;

    // Determine eco level
    String ecoLevel;
    Color ecoLevelColor;

    if (co2SavedPerMonth >= 100) {
      ecoLevel = 'Planet Saver 🌍';
      ecoLevelColor = const Color(0xFF06d6a0);
    } else if (co2SavedPerMonth >= 50) {
      ecoLevel = 'Green Commuter 🌱';
      ecoLevelColor = const Color(0xFF4a90e2);
    } else if (co2SavedPerMonth > 0) {
      ecoLevel = 'Eco Beginner 🌿';
      ecoLevelColor = const Color(0xFFffa726);
    } else {
      ecoLevel = 'Eco Beginner';
      ecoLevelColor = const Color(0xFF9e9e9e);
    }

    setState(() {
      _co2SavedPerMonth = co2SavedPerMonth;
      _fuelSavedPerMonth = fuelSavedPerMonth;
      _moneySavedPerMonth = moneySavedPerMonth;
      _ecoLevel = ecoLevel;
      _ecoLevelColor = ecoLevelColor;
      _showStats = true; // Show stats after calculation
    });

    // Trigger animation
    _animationController.forward(from: 0);
    _animationController.forward();
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
          'Impact Tracker',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFf5f6fa),
          ),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF06d6a0)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06d6a0), Color(0xFF05b48a)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.eco,
                            size: 32,
                            color: const Color(0xFF1c1c1c),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calculate Your Impact',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1c1c1c),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'See how much you save by using public transport',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: const Color(0xFF1c1c1c),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // User's Vehicle Info (if available)
                  if (_userVehicleType != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a2a2a),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3a3a3a)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _userVehicleType == 'car'
                                ? Icons.directions_car
                                : Icons.two_wheeler,
                            color: const Color(0xFF06d6a0),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Vehicle',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Color(0xFF9e9e9e),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_userVehicleType?.toUpperCase()} • ${_userVehicleFuel?.toUpperCase()}',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFf5f6fa),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06d6a0).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'From Profile',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF06d6a0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Input Section
                  const Text(
                    'Trip Details',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFf5f6fa),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Distance Input
                  _buildTextField(
                    controller: _distanceController,
                    label: 'Average Distance per Trip (km)',
                    hint: 'e.g., 10',
                    icon: Icons.straighten,
                  ),
                  const SizedBox(height: 16),

                  // Trips per Week Input
                  _buildTextField(
                    controller: _tripsController,
                    label: 'Trips per Week',
                    hint: 'e.g., 10',
                    icon: Icons.repeat,
                  ),
                  const SizedBox(height: 24),

                  // Transport Mode Selection
                  const Text(
                    'Transport Modes',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFf5f6fa),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Usual Mode
                  _buildDropdown(
                    label: 'Usual Mode',
                    value: _usualMode,
                    items: ['Car', 'Bike', 'Bus'],
                    icon: Icons.directions_car,
                    onChanged: (value) => setState(() => _usualMode = value!),
                  ),
                  const SizedBox(height: 16),

                  // Alternate Mode
                  _buildDropdown(
                    label: 'Alternate Mode (Public Transport)',
                    value: _alternateMode,
                    items: ['Train', 'Metro', 'Bus'],
                    icon: Icons.train,
                    onChanged: (value) =>
                        setState(() => _alternateMode = value!),
                  ),
                  const SizedBox(height: 16),

                  // Fuel Type
                  _buildDropdown(
                    label: 'Fuel Type',
                    value: _fuelType,
                    items: ['Petrol', 'Diesel', 'Electric'],
                    icon: Icons.local_gas_station,
                    onChanged: (value) => setState(() => _fuelType = value!),
                  ),
                  const SizedBox(height: 32),

                  // Calculate Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _calculateImpact,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06d6a0),
                        foregroundColor: const Color(0xFF1c1c1c),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calculate, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Calculate Impact',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Results Section
                  if (_showStats && _co2SavedPerMonth > 0) ...[
                    const Text(
                      'Your Environmental Impact',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFf5f6fa),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Impact Cards
                    _buildImpactCard(
                      icon: Icons.cloud_outlined,
                      title: 'CO₂ Saved per Month',
                      value: '${_co2SavedPerMonth.toStringAsFixed(1)} kg',
                      color: const Color(0xFF06d6a0),
                      subtitle:
                          'Equivalent to planting ${(_co2SavedPerMonth / 21).toStringAsFixed(0)} trees',
                    ),
                    const SizedBox(height: 16),

                    _buildImpactCard(
                      icon: Icons.local_gas_station,
                      title: 'Fuel Saved per Month',
                      value:
                          '${_fuelSavedPerMonth.toStringAsFixed(1)} ${_fuelType == "Electric" ? "kWh" : "L"}',
                      color: const Color(0xFF4a90e2),
                      subtitle: _fuelType == 'Electric'
                          ? 'Electricity saved'
                          : 'Fuel not consumed',
                    ),
                    const SizedBox(height: 16),

                    _buildImpactCard(
                      icon: Icons.currency_rupee,
                      title: 'Money Saved per Month',
                      value: '₹${_moneySavedPerMonth.toStringAsFixed(0)}',
                      color: const Color(0xFFffa726),
                      subtitle:
                          'Annual savings: ₹${(_moneySavedPerMonth * 12).toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 16),

                    _buildImpactCard(
                      icon: Icons.emoji_events,
                      title: 'Your Eco Level',
                      value: _ecoLevel,
                      color: _ecoLevelColor,
                      subtitle: _getEcoLevelDescription(),
                      isEcoLevel: true,
                    ),
                    const SizedBox(height: 32),

                    // Impact Summary
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _ecoLevelColor.withOpacity(0.2),
                            _ecoLevelColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _ecoLevelColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: _ecoLevelColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Impact Summary',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFf5f6fa),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getImpactSummary(),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              height: 1.6,
                              color: Color(0xFFf5f6fa),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFf5f6fa),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Color(0xFFf5f6fa),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFF7a7a7a),
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF06d6a0)),
            filled: true,
            fillColor: const Color(0xFF2a2a2a),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFf5f6fa),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a2a),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Color(0xFFf5f6fa),
                  ),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              onChanged(newValue);
            },
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF06d6a0)),
            dropdownColor: const Color(0xFF2a2a2a),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF06d6a0)),
              filled: true,
              fillColor: const Color(0xFF2a2a2a),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImpactCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String subtitle,
    bool isEcoLevel = false,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * animValue),
          child: Opacity(
            opacity: animValue,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2a2a2a),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Color(0xFF9e9e9e),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: isEcoLevel ? 20 : 24,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF7a7a7a),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getEcoLevelDescription() {
    if (_co2SavedPerMonth >= 100) {
      return 'Amazing! You\'re a climate champion!';
    } else if (_co2SavedPerMonth >= 50) {
      return 'Great work! Keep it up!';
    } else {
      return 'Good start! Every bit counts!';
    }
  }

  String _getImpactSummary() {
    final distance = double.tryParse(_distanceController.text) ?? 0;
    final trips = double.tryParse(_tripsController.text) ?? 0;
    final weeklyTrips = trips.toInt();
    final monthlyTrips = (trips * 4).toInt();

    return 'By switching from $_usualMode to $_alternateMode for your ${distance.toStringAsFixed(0)} km trips ($weeklyTrips trips/week), you\'re making $monthlyTrips sustainable journeys per month. This prevents ${_co2SavedPerMonth.toStringAsFixed(1)} kg of CO₂ emissions, which is like planting ${(_co2SavedPerMonth / 21).toStringAsFixed(0)} trees every month! Plus, you save ₹${_moneySavedPerMonth.toStringAsFixed(0)} monthly - that\'s ₹${(_moneySavedPerMonth * 12).toStringAsFixed(0)} annually! Keep making a difference! 🌍';
  }
}
