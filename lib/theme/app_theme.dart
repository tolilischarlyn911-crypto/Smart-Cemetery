import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF1B4D2E);
  static const Color accentGreen = Color(0xFF517C5B);
  static const Color backgroundColor = Color(0xFFF2F6F3);
  static const Color cardColor = Colors.white;
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textMuted = Color(0xFF7F8C8D);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: primaryGreen,
        secondary: accentGreen,
      ),
    );
  }
}
