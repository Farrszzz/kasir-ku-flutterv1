import 'package:flutter/material.dart';

class AppTheme {
  // Warna dasar
  static const Color backgroundColor = Color(0xFFFFFFFF); // putih
  static const Color primaryColor = Color(0xFF004CCE); // biru utama
  static const Color secondaryColor = Color(0xFFF5F7FA); // abu soft
  static const Color textPrimaryColor = Color(0xFF333333); // text utama
  static const Color textSecondaryColor = Color(0xFF777777); // text sekunder
  static const Color borderColor = Color(0xFFE5E5E5); // border tipis

  // Radius
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;
  static const double modalBorderRadius = 20.0;

  // Spacing
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // Elevation
  static const double cardElevation = 2.0;
  
  // Font sizes
  static const double bodyFontSize = 14.0;
  static const double titleFontSize = 16.0;
  static const double headingFontSize = 18.0;

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        background: backgroundColor,
        surface: backgroundColor,
        onPrimary: Colors.white,
        onSecondary: textPrimaryColor,
        onBackground: textPrimaryColor,
        onSurface: textPrimaryColor,
      ),
      
      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: primaryColor,
          fontSize: headingFontSize,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      
      // Navigation Bar Theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: backgroundColor,
        indicatorColor: primaryColor.withOpacity(0.1),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: primaryColor, fontSize: 12);
          }
          return const TextStyle(color: textSecondaryColor, fontSize: 12);
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: textSecondaryColor);
        }),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: backgroundColor,
        elevation: cardElevation,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.all(smallPadding),
      ),
      
      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: defaultPadding, vertical: smallPadding),
        tileColor: backgroundColor,
        textColor: textPrimaryColor,
        iconColor: primaryColor,
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
          backgroundColor: MaterialStateProperty.all<Color>(primaryColor),
          elevation: MaterialStateProperty.all<double>(0),
          padding: MaterialStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.symmetric(horizontal: defaultPadding, vertical: smallPadding)),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonBorderRadius),
            ),
          ),
          textStyle: MaterialStateProperty.all<TextStyle>(const TextStyle(
            fontSize: bodyFontSize,
            fontWeight: FontWeight.bold,
          )),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all<Color>(primaryColor),
          side: MaterialStateProperty.all<BorderSide>(const BorderSide(color: primaryColor)),
          padding: MaterialStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.symmetric(horizontal: defaultPadding, vertical: smallPadding)),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonBorderRadius),
            ),
          ),
          textStyle: MaterialStateProperty.all<TextStyle>(const TextStyle(
            fontSize: bodyFontSize,
            fontWeight: FontWeight.bold,
          )),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all<Color>(primaryColor),
          padding: MaterialStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.symmetric(horizontal: defaultPadding, vertical: smallPadding)),
          textStyle: MaterialStateProperty.all<TextStyle>(const TextStyle(
            fontSize: bodyFontSize,
            fontWeight: FontWeight.bold,
          )),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryColor,
        contentPadding: const EdgeInsets.all(defaultPadding),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
          borderSide: const BorderSide(color: primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
          borderSide: const BorderSide(color: Colors.red),
        ),
        labelStyle: const TextStyle(color: textSecondaryColor),
        hintStyle: const TextStyle(color: textSecondaryColor),
      ),
      
      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: backgroundColor,
        elevation: cardElevation,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(modalBorderRadius),
        ),
      ),
      
      // Typography
      textTheme: TextTheme(
        displayLarge: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        displayMedium: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        displaySmall: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        headlineLarge: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        headlineMedium: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        headlineSmall: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: headingFontSize),
        titleLarge: const TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold, fontSize: titleFontSize),
        titleMedium: const TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold, fontSize: titleFontSize),
        titleSmall: const TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold),
        bodyLarge: const TextStyle(color: textPrimaryColor, fontSize: bodyFontSize),
        bodyMedium: const TextStyle(color: textPrimaryColor, fontSize: bodyFontSize),
        bodySmall: const TextStyle(color: textSecondaryColor, fontSize: 12),
        labelLarge: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        labelMedium: const TextStyle(color: primaryColor),
        labelSmall: const TextStyle(color: textSecondaryColor),
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: defaultPadding,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: primaryColor,
        size: 24,
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
        ),
      ),
    );
  }
}