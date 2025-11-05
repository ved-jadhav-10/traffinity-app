import 'package:flutter/material.dart';
import 'dart:async';
import 'onboarding_screen.dart';
import 'home_page.dart';
import 'services/supabase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for 3 seconds to show splash screen
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Check if user is authenticated
    final isAuthenticated = SupabaseService().isAuthenticated;

    // Navigate based on authentication status
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            isAuthenticated ? const HomePage() : const OnboardingScreen(),
      ),
    );
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
            Image.asset('assets/images/logo.png', width: 180, height: 180),
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
