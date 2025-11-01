import 'package:flutter/material.dart';
import 'dart:async';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to onboarding page after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c), // Black background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo image
            Image.asset(
              'assets/images/logo.png',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 30),
            // App name with custom font
            const Text(
              'TRAFFINITY',
              style: TextStyle(
                fontFamily: 'CormorantSC',
                fontSize: 32,
                fontWeight: FontWeight.w500,
                color: Color(0xFF06d6a0), // Green color
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder HomePage - replace this with your actual home page
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traffinity'),
        backgroundColor: const Color(0xFF06d6a0), // Green color
      ),
      body: const Center(
        child: Text('Welcome to Traffinity!'),
      ),
    );
  }
}
