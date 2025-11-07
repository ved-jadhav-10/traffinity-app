import 'package:flutter/material.dart';

class TerritoryPage extends StatefulWidget {
  final VoidCallback? onExploreNearby;

  const TerritoryPage({super.key, this.onExploreNearby});

  @override
  State<TerritoryPage> createState() => _TerritoryPageState();
}

class _TerritoryPageState extends State<TerritoryPage> {
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
                        'assets/images/territory.png',
                        width: 32,
                        height: 32,
                        color: const Color(0xFF06d6a0),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Territory',
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
                  'Discover, explore, and save your favorite places and routes.',
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
                  icon: Icons.explore,
                  title: 'Explore Nearby',
                  description: 'Discover interesting places around you.',
                  color: const Color(0xFF06d6a0),
                  onTap: widget.onExploreNearby,
                ),
                const SizedBox(height: 16),

                _buildFeatureCard(
                  icon: Icons.business_center,
                  title: 'Our Services',
                  description: 'Check our website for more services and features!',
                  color: const Color(0xFFf54748),
                ),
                const SizedBox(height: 16),

                _buildFeatureCard(
                  icon: Icons.report_problem,
                  title: 'City Incident Map',
                  description: 'A live map of all traffic jams, accidents, event or weather related delays.',
                  color: const Color(0xFF4a90e2),
                ),
                const SizedBox(height: 16),

                _buildFeatureCard(
                  icon: Icons.collections,
                  title: 'Collections',
                  description: 'Organize places into custom collections.',
                  color: const Color(0xFFffa726),
                ),
                const SizedBox(height: 16),

                _buildFeatureCard(
                  icon: Icons.people,
                  title: 'Friends',
                  description: 'See what your friends are up to!',
                  color: const Color(0xFF9c27b0),
                ),
                const SizedBox(height: 32),

                // Coming Soon Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF06d6a0), Color(0xFF05b48a)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.construction,
                        size: 48,
                        color: Color(0xFF1c1c1c),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Coming Soon',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1c1c1c),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Get ready to explore and save your world!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF1c1c1c),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100), // Extra padding for bottom nav
              ],
            ),
          ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
