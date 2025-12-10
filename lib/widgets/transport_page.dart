import 'package:flutter/material.dart';
import '../screens/transport/train_search_screen.dart';
import '../screens/transport/bus_search_screen.dart';
import '../screens/transport/impact_tracker_calculator.dart';
import '../screens/trips/my_trips_screen.dart';

class TransportPage extends StatefulWidget {
  const TransportPage({super.key});

  @override
  State<TransportPage> createState() => _TransportPageState();
}

class _TransportPageState extends State<TransportPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a2a2a),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        'assets/images/transport.png',
                        width: 32,
                        height: 32,
                        color: const Color(0xFF06d6a0),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Transport',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFf5f6fa),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Description
                const Text(
                  'Track routes, check your impact and plan trips efficiently.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Color(0xFF9e9e9e),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Feature Cards Section
                _buildFeatureCard(
                  icon: Icons.directions_bus,
                  title: 'Public Transport',
                  description:
                      'View bus, train and metro routes and schedules in your area.',
                  color: const Color(0xFFffa726),
                  onTap: () => _showPublicTransportOptions(context),
                ),
                const SizedBox(height: 16),

                _buildFeatureCard(
                  icon: Icons.eco,
                  title: 'Impact Tracker',
                  description:
                      'Compare transportation methods to see your carbon footprint and money saved.',
                  color: const Color(0xFF06d6a0),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ImpactTrackerCalculator(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                _buildFeatureCard(
                  icon: Icons.event_note,
                  title: 'My Trips',
                  description: 'Plan your trips and save them in a log.',
                  color: const Color(0xFFf54748),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyTripsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 100), // Extra padding for bottom nav
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show public transport options dialog
  void _showPublicTransportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2a2a2a),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              'Select Transport Type',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 24),

            // Trains Option
            _buildTransportOption(
              context: context,
              icon: Icons.train,
              title: 'Trains',
              description: 'Search and track Indian Railways trains',
              color: const Color(0xFF06d6a0),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrainSearchScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Buses Option
            _buildTransportOption(
              context: context,
              icon: Icons.directions_bus,
              title: 'Buses',
              description: 'Search and track city buses',
              color: const Color(0xFFffa726),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BusSearchScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1c1c1c),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3a3a3a), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFf5f6fa),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Color(0xFF9e9e9e),
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

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3a3a3a), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFf5f6fa),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Color(0xFF9e9e9e),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
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
}
