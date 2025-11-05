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
              width: 180,
              height: 180,
            ),
            const SizedBox(height: 40),
            // App name with custom font - "TRAF" in white, "FINITY" in green
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'CormorantSC',
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
                children: [
                  TextSpan(
                    text: 'TRAF',
                    style: TextStyle(
                      color: Color(0xFFf5f6fa), // White color
                    ),
                  ),
                  TextSpan(
                    text: 'FINITY',
                    style: TextStyle(
                      color: Color(0xFF06d6a0), // Green color
                    ),
                  ),
                ],
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
