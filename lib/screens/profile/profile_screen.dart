import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';
import '../../home_page.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;

  const ProfileScreen({super.key, this.showBackButton = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Vehicle controllers (up to 3)
  final List<Map<String, dynamic>> _vehicles = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await _supabaseService.getUserProfile();

      if (mounted) {
        setState(() {
          _nameController.text = profile['name'] ?? '';
          _phoneController.text = profile['phone_number'] ?? '';

          // Load vehicles
          final vehiclesJson = profile['vehicles'] as List<dynamic>?;
          if (vehiclesJson != null) {
            _vehicles.clear();
            for (var vehicle in vehiclesJson) {
              _vehicles.add({
                'type': vehicle['type'] ?? 'car',
                'model': vehicle['model'] ?? '',
                'fuel': vehicle['fuel'] ?? 'petrol',
                'typeController': TextEditingController(
                  text: vehicle['model'] ?? '',
                ),
              });
            }
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading profile: ${e.toString()}', isError: true);
      }
    }
  }

  void _addVehicle() {
    if (_vehicles.length < 3) {
      setState(() {
        _vehicles.add({
          'type': 'car',
          'model': '',
          'fuel': 'petrol',
          'typeController': TextEditingController(),
        });
      });
    }
  }

  void _removeVehicle(int index) {
    setState(() {
      _vehicles[index]['typeController'].dispose();
      _vehicles.removeAt(index);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Prepare vehicles data
      final vehiclesData = _vehicles
          .where((v) => v['model'].toString().isNotEmpty)
          .map(
            (v) => {
              'type': v['type'],
              'model': v['typeController'].text.trim(),
              'fuel': v['fuel'],
            },
          )
          .toList();

      // Update profile
      await _supabaseService.updateUserProfile(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        vehicles: vehiclesData,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('Profile updated successfully!');

        // Reload profile to ensure sync
        await _loadUserProfile();

        // If this was opened from sign-in (no back button), redirect to home
        if (!widget.showBackButton) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('Error saving profile: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar('Please fill all password fields', isError: true);
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('New passwords do not match', isError: true);
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _supabaseService.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
        _showSnackBar('Password updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar(
          'Error changing password: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: isError
            ? Colors.red.shade700
            : const Color(0xFF06d6a0),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1c1c1c),
        elevation: 0,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFf5f6fa)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        automaticallyImplyLeading: widget.showBackButton,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFFf5f6fa),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06d6a0)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06d6a0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 64,
                          color: Color(0xFF1c1c1c),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name Field
                    _buildSectionTitle('Personal Information'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Field
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          // Basic phone validation (10 digits)
                          if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                            return 'Please enter a valid 10-digit phone number';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Vehicles Section
                    _buildSectionTitle('Vehicles (Optional)'),
                    const SizedBox(height: 8),
                    const Text(
                      'Add up to 3 vehicles',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Color(0xFF9e9e9e),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Show vehicle cards if any exist
                    if (_vehicles.isNotEmpty)
                      ..._vehicles.asMap().entries.map((entry) {
                        final index = entry.key;
                        final vehicle = entry.value;
                        return _buildVehicleCard(index, vehicle);
                      }).toList(),

                    // Add Vehicle Button
                    if (_vehicles.length < 3)
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _addVehicle,
                          icon: const Icon(Icons.add, color: Color(0xFF06d6a0)),
                          label: Text(
                            _vehicles.isEmpty
                                ? 'Add Vehicle'
                                : 'Add Another Vehicle',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color(0xFF06d6a0),
                              fontSize: 15,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF06d6a0)),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Password Section
                    _buildSectionTitle('Change Password'),
                    const SizedBox(height: 16),

                    _buildPasswordField(
                      controller: _currentPasswordController,
                      label: 'Current Password',
                      obscureText: _obscureCurrentPassword,
                      onToggle: () {
                        setState(() {
                          _obscureCurrentPassword = !_obscureCurrentPassword;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _newPasswordController,
                      label: 'New Password',
                      obscureText: _obscureNewPassword,
                      onToggle: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm New Password',
                      obscureText: _obscureConfirmPassword,
                      onToggle: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // Update Password Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06d6a0),
                          foregroundColor: const Color(0xFF1c1c1c),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1c1c1c),
                                  ),
                                ),
                              )
                            : const Text(
                                'Update Password',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06d6a0),
                          foregroundColor: const Color(0xFF1c1c1c),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1c1c1c),
                                  ),
                                ),
                              )
                            : const Text(
                                'Save Profile',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFFf5f6fa),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        color: Color(0xFFf5f6fa),
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: Color(0xFF9e9e9e),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF06d6a0)),
        filled: true,
        fillColor: const Color(0xFF2a2a2a),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3a3a3a), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF06d6a0), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        color: Color(0xFFf5f6fa),
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: Color(0xFF9e9e9e),
        ),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF06d6a0)),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: const Color(0xFF9e9e9e),
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFF2a2a2a),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3a3a3a), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF06d6a0), width: 2),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(int index, Map<String, dynamic> vehicle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3a3a3a), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vehicle ${index + 1}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFf5f6fa),
                ),
              ),
              if (_vehicles.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeVehicle(index),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Vehicle Type Dropdown
          DropdownButtonFormField<String>(
            value: vehicle['type'],
            dropdownColor: const Color(0xFF2a2a2a),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: Color(0xFFf5f6fa),
            ),
            decoration: InputDecoration(
              labelText: 'Type',
              labelStyle: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFF9e9e9e),
              ),
              prefixIcon: const Icon(
                Icons.directions_car,
                color: Color(0xFF06d6a0),
              ),
              filled: true,
              fillColor: const Color(0xFF1c1c1c),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: ['car', 'bike'].map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.toUpperCase()),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                vehicle['type'] = value!;
              });
            },
          ),
          const SizedBox(height: 12),

          // Model Text Field
          TextFormField(
            controller: vehicle['typeController'],
            onChanged: (value) {
              vehicle['model'] = value;
            },
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: Color(0xFFf5f6fa),
            ),
            decoration: InputDecoration(
              labelText: 'Model',
              labelStyle: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFF9e9e9e),
              ),
              prefixIcon: const Icon(Icons.edit, color: Color(0xFF06d6a0)),
              filled: true,
              fillColor: const Color(0xFF1c1c1c),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Fuel Type Dropdown
          DropdownButtonFormField<String>(
            value: vehicle['fuel'],
            dropdownColor: const Color(0xFF2a2a2a),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: Color(0xFFf5f6fa),
            ),
            decoration: InputDecoration(
              labelText: 'Fuel Type',
              labelStyle: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFF9e9e9e),
              ),
              prefixIcon: const Icon(
                Icons.local_gas_station,
                color: Color(0xFF06d6a0),
              ),
              filled: true,
              fillColor: const Color(0xFF1c1c1c),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: ['petrol', 'diesel', 'cng', 'ev'].map((fuel) {
              return DropdownMenuItem(
                value: fuel,
                child: Text(fuel.toUpperCase()),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                vehicle['fuel'] = value!;
              });
            },
          ),
        ],
      ),
    );
  }
}
