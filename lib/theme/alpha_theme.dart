import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AlphaTheme {
  // Alpha.gr Color Palette
  static const Color primaryBlue = Color(0xFF005AA3);
  static const Color secondaryBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFF57C00);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color darkGray = Color(0xFF333333);
  static const Color white = Color(0xFFFFFFFF);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color warningYellow = Color(0xFFFFA000);

  // Text Styles
  static final TextStyle headingLarge = GoogleFonts.roboto(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: darkGray,
  );

  static final TextStyle headingMedium = GoogleFonts.roboto(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: darkGray,
  );

  static final TextStyle headingSmall = GoogleFonts.roboto(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: darkGray,
  );

  static final TextStyle bodyLarge = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: darkGray,
  );

  static final TextStyle bodyMedium = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: darkGray.withOpacity(0.7),
  );

  static final TextStyle bodySmall = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: darkGray.withOpacity(0.6),
  );

  static final TextStyle buttonText = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: white,
  );

  // Theme Data - FIXED VERSION
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryBlue,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: accentOrange,
        surface: white,
      ),
      scaffoldBackgroundColor: lightGray,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlue,
        elevation: 2,
        titleTextStyle: headingSmall.copyWith(color: white),
        iconTheme: const IconThemeData(color: white),
      ),
      textTheme: TextTheme(
        displayLarge: headingLarge,
        displayMedium: headingMedium,
        displaySmall: headingSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
      ),
      // FIXED: Use CardTheme instead of CardThemeData
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: buttonText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: bodyMedium.copyWith(color: darkGray.withOpacity(0.6)),
        hintStyle: bodyMedium.copyWith(color: darkGray.withOpacity(0.4)),
      ),
    );
  }

  // Custom Box Decorations
  static BoxDecoration get cardDecoration {
    return BoxDecoration(
      color: white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration get gradientCardDecoration {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryBlue, secondaryBlue],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: primaryBlue.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
