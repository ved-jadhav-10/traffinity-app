import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../config/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      _showSnackBar('Please select a rating', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = _supabaseService.currentUser?.id;
      
      await SupabaseService.client.from('feedback').insert({
        'user_id': userId,
        'rating': _rating,
        'feedback_text': _feedbackController.text.trim().isEmpty 
            ? null 
            : _feedbackController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _showSnackBar('Thank you for your feedback!', isError: false);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to submit feedback. Please try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFFf5f6fa),
          ),
        ),
        backgroundColor: isError ? Colors.red.shade700 : AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
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
          'Feedback',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFf5f6fa),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'We value your feedback',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Help us improve your experience with Traffinity',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFF9e9e9e),
              ),
            ),
            const SizedBox(height: 40),

            // Rating Section
            const Text(
              'How would you rate your experience?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 16),
            
            // Star Rating
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(
                        _rating > index ? Icons.star : Icons.star_border,
                        size: 48,
                        color: _rating > index 
                            ? AppTheme.primaryGreen 
                            : const Color(0xFF3a3a3a),
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            if (_rating > 0)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _getRatingText(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 40),

            // Feedback Text Section
            const Text(
              'Tell us more (optional)',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 12),

            // Text Field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2a2a2a),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3a3a3a),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _feedbackController,
                maxLines: 6,
                maxLength: 500,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFFf5f6fa),
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Share your thoughts, suggestions, or report issues...',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF9e9e9e),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  counterStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF9e9e9e),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  disabledBackgroundColor: const Color(0xFF3a3a3a),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF1c1c1c),
                          ),
                        ),
                      )
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1c1c1c),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText() {
    switch (_rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}
