import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/auth/sign_in_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      image: 'assets/images/onboarding_1.png',
      frameImage: 'assets/images/frame 1.png',
      progress: 'assets/images/onboarding 1 progress.png',
      title: 'Choose the way that suits you, not just the shortest one.',
      subtitle: 'Smarter routes, safer rides, real-time insights.',
    ),
    OnboardingPage(
      image: 'assets/images/onboarding_2.png',
      frameImage: 'assets/images/frame 2.png',
      progress: 'assets/images/onboarding 2 progress.png',
      title: 'See your city come to life in real time.',
      subtitle: 'From parking to pollution, everything is one glance away.',
    ),
    OnboardingPage(
      image: 'assets/images/onboarding_3.png',
      frameImage: 'assets/images/frame 3.png',
      progress: 'assets/images/onboarding progress 3.png',
      title: 'Stay on track with live GPS based bus and rail updates.',
      subtitle: 'Save time, money, and make every trip eco-friendly.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _skipToEnd() {
    _pageController.animateToPage(
      _pages.length,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          if (_currentPage < _pages.length - 1)
            TextButton(
              onPressed: _skipToEnd,
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Color(0xFF06d6a0),
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          ..._pages.map((page) => _buildOnboardingPage(page)),
          _buildFinalPage(),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Image
          Image.asset(
            page.image,
            height: 280,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          ),
          const SizedBox(height: 60),
          // Title
          Text(
            page.title,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Color(0xFFf5f6fa),
              fontSize: 24,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Color(0xFFf5f6fa),
              fontSize: 16,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.normal,
              height: 1.5,
            ),
          ),
          const Spacer(),
          // Progress indicator and next button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Frame image (page indicator)
              Image.asset(page.frameImage, height: 8, fit: BoxFit.contain),
              // Next button
              GestureDetector(
                onTap: _nextPage,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06d6a0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF06d6a0),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Color(0xFF1c1c1c),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFinalPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Image
          Image.asset(
            'assets/images/onboarding_4.png',
            height: 280,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          ),
          const SizedBox(height: 60),
          // Title
          const Text(
            'Get Started!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFf5f6fa),
              fontSize: 32,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Create Account button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUpScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf5f6fa),
                foregroundColor: const Color(0xFF1c1c1c),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Sign In button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignInScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF06d6a0),
                side: const BorderSide(color: Color(0xFF06d6a0), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String image;
  final String frameImage;
  final String progress;
  final String title;
  final String subtitle;

  OnboardingPage({
    required this.image,
    required this.frameImage,
    required this.progress,
    required this.title,
    required this.subtitle,
  });
}
