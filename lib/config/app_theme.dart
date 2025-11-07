import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryGreen = Color(0xFF06d6a0);
  static const Color darkBackground = Color(0xFF1c1c1c);
  static const Color cardBackground = Color(0xFF2a2a2a);
  static const Color borderColor = Color(0xFF3a3a3a);
  
  // Text Colors
  static const Color textPrimary = Color(0xFFf5f6fa);
  static const Color textSecondary = Color(0xFF9e9e9e);
  
  // Alert Colors
  static const Color errorRed = Color(0xFFf54748);
  static const Color warningOrange = Color(0xFFf57c00);
  
  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;
  static const double spacingXXXL = 32.0;
  
  // Border Radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
  
  // Font Sizes
  static const double fontSizeXS = 10.0;
  static const double fontSizeS = 12.0;
  static const double fontSizeM = 14.0;
  static const double fontSizeL = 16.0;
  static const double fontSizeXL = 18.0;
  static const double fontSizeXXL = 20.0;
  static const double fontSizeXXXL = 24.0;
  static const double fontSizeHuge = 32.0;
  static const double fontSizeGiant = 48.0;
  
  // Icon Sizes
  static const double iconSizeS = 16.0;
  static const double iconSizeM = 20.0;
  static const double iconSizeL = 24.0;
  static const double iconSizeXL = 32.0;
  static const double iconSizeXXL = 48.0;
  
  // Font Family
  static const String fontFamily = 'Poppins';
  
  // Text Styles
  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeHuge,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeXXXL,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeXXL,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeL,
    color: textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeM,
    color: textPrimary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeS,
    color: textSecondary,
  );
  
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeXS,
    color: textSecondary,
  );
  
  // Box Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 12,
      spreadRadius: 2,
    ),
  ];
  
  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.5),
      blurRadius: 12,
      spreadRadius: 4,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 8,
      spreadRadius: 2,
    ),
  ];
}
