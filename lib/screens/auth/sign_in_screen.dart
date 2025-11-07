import 'package:flutter/material.dart';
import 'package:traffinity/services/supabase_service.dart';
import 'package:traffinity/screens/auth/sign_up_screen.dart';
import 'package:traffinity/screens/auth/phone_sign_in_screen.dart';
import '../../screens/profile/profile_screen.dart';
import 'package:traffinity/home_page.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService().signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Check if user exists and is confirmed
      if (response.user == null) {
        throw Exception('No user returned from sign in');
      }

      if (mounted) {
        // Check if user needs to complete profile
        final profile = await SupabaseService().getUserProfile();
        final name = profile['name'] as String?;
        final needsDetails =
            name == null || name.trim().isEmpty || name.trim() == 'User';

        if (needsDetails) {
          // Redirect to profile screen to complete details
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
            (route) => false,
          );

          // Show message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please complete your profile to continue',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              backgroundColor: Color(0xFF06d6a0),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // Navigate to home screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().toLowerCase();
        print('Sign in error: $errorMessage'); // Debug log

        // Check if the error is due to user not found or invalid credentials
        if (errorMessage.contains('invalid login credentials') ||
            errorMessage.contains('invalid_credentials') ||
            errorMessage.contains('user not found') ||
            errorMessage.contains('email not confirmed') ||
            errorMessage.contains('invalid email or password')) {
          // Show dialog asking user to sign up
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF2a2a2a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Account Not Found',
                style: TextStyle(
                  color: Color(0xFFf5f6fa),
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: const Text(
                'It looks like you don\'t have an account yet. Would you like to sign up?',
                style: TextStyle(
                  color: Color(0xFFf5f6fa),
                  fontFamily: 'Poppins',
                ),
              ),
              actions: [
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
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignUpScreen(
                          initialEmail: _emailController.text.trim(),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06d6a0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: Color(0xFF1c1c1c),
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Show generic error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign in failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final success = await SupabaseService().signInWithGoogle();
      if (success && mounted) {
        // Check if this is a new user (just created by OAuth)
        final user = SupabaseService().currentUser;

        if (user != null) {
          // Check if profile exists in database
          final profileExists = await _checkProfileExists(user.id);

          if (!profileExists) {
            // New user - redirect to complete profile/sign up
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SignUpScreen(initialEmail: user.email ?? ''),
                ),
              );

              // Show message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please complete your profile to continue'),
                  backgroundColor: Color(0xFF06d6a0),
                ),
              );
              return;
            }
          }
        }

        // Existing user - navigate to home
        if (mounted) {
          // Check if user needs to complete profile
          final profile = await SupabaseService().getUserProfile();
          final name = profile['name'] as String?;
          final needsDetails =
              name == null || name.trim().isEmpty || name.trim() == 'User';

          if (needsDetails) {
            // Redirect to profile screen to complete details
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const ProfileScreen(showBackButton: false),
              ),
              (route) => false,
            );

            // Show message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please complete your profile to continue',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
                backgroundColor: Color(0xFF06d6a0),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            // Navigate to home screen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _checkProfileExists(String userId) async {
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking profile: $e');
      // If error, assume profile exists to avoid blocking
      return true;
    }
  }

  void _navigateToPhoneSignIn() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PhoneSignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFf5f6fa)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sign In',
          style: TextStyle(
            color: Color(0xFFf5f6fa),
            fontSize: 20,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Email Address
              _buildLabel('Email Address'),
              _buildTextField(
                controller: _emailController,
                hintText: 'Email Address',
                prefixIcon: 'assets/images/email_logo.png',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Password
              _buildLabel('Password'),
              _buildPasswordField(),
              const SizedBox(height: 12),

              // Forgot Password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // TODO: Implement forgot password
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Color(0xFF06d6a0),
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Sign In button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf5f6fa),
                    foregroundColor: const Color(0xFF1c1c1c),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1c1c1c),
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Container(height: 1, color: const Color(0xFF3a3a3a)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Or continue with',
                      style: TextStyle(
                        color: Color(0xFF9e9e9e),
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(height: 1, color: const Color(0xFF3a3a3a)),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Google Sign In button
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFf5f6fa),
                    side: const BorderSide(color: Color(0xFF3a3a3a), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: Image.asset(
                    'assets/images/google.png',
                    height: 24,
                    width: 24,
                  ),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Phone Sign In button
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _navigateToPhoneSignIn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFf5f6fa),
                    side: const BorderSide(color: Color(0xFF3a3a3a), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: const Icon(Icons.phone_android, size: 24),
                  label: const Text(
                    'Continue with Phone',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Sign Up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: Color(0xFF9e9e9e),
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Color(0xFF06d6a0),
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFf5f6fa),
          fontSize: 14,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String prefixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          color: Color(0xFFf5f6fa),
          fontSize: 16,
          fontFamily: 'Poppins',
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF6a6a6a),
            fontSize: 16,
            fontFamily: 'Poppins',
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Image.asset(
              prefixIcon,
              height: 24,
              width: 24,
              color: const Color(0xFF6a6a6a),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your password';
          }
          return null;
        },
        style: const TextStyle(
          color: Color(0xFFf5f6fa),
          fontSize: 16,
          fontFamily: 'Poppins',
        ),
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: const TextStyle(
            color: Color(0xFF6a6a6a),
            fontSize: 16,
            fontFamily: 'Poppins',
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Image.asset(
              'assets/images/password_icon.png',
              height: 24,
              width: 24,
              color: const Color(0xFF6a6a6a),
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFF6a6a6a),
            ),
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
