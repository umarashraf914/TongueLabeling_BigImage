import 'package:flutter/material.dart';

/// Application-wide constants for consistent UI styling and behavior
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // ========== COLORS ==========
  /// Soft white-purplish background color used throughout the app
  static const Color cardBackgroundColor = Color(0xFFF3EFFF);
  
  /// Primary purple color for icons and accents
  static const Color primaryPurple = Colors.deepPurple;
  
  /// Secondary colors for labeling
  static const Color paleColor = Color(0xFFFFE4E1);
  static const Color pinkColor = Color(0xFFFFB6C1);
  static const Color redColor = Color(0xFFFF6B6B);
  static const Color deepRedColor = Color(0xFF8B0000);

  // ========== ELEVATIONS ==========
  /// Standard card elevation for most UI elements
  static const double standardElevation = 8.0;
  
  /// Card elevation (alias for standardElevation)
  static const double cardElevation = 8.0;
  
  /// Higher elevation for prominent elements like mode selection
  static const double highElevation = 12.0;
  
  /// No elevation for flat buttons and embedded elements
  static const double noElevation = 0.0;

  // ========== DIMENSIONS ==========
  /// Standard border radius for cards and buttons
  static const double standardBorderRadius = 32.0;
  
  /// Card border radius (alias for standardBorderRadius)
  static const double cardBorderRadius = 32.0;
  
  /// Standard card height for action bars
  static const double standardCardHeight = 56.0;
  
  /// Taller toolbar height for custom app bars
  static const double customToolbarHeight = 72.0;
  
  /// Standard padding for card content
  static const EdgeInsets standardCardPadding = EdgeInsets.symmetric(horizontal: 8.0);
  
  /// Standard spacing between UI elements
  static const double standardSpacing = 8.0;
  static const double mediumSpacing = 12.0;
  static const double largeSpacing = 16.0;

  // ========== IMAGE DIMENSIONS ==========
  /// Maximum image box size for labeling screens
  static const double maxImageBoxSize = 400.0;
  
  /// Default image box width
  static const double defaultImageBoxWidth = 320.0;
  
  /// Standard aspect ratio for image display
  static const double imageAspectRatio = 3.0 / 4.0;

  // ========== DATABASE ==========
  /// Database version for schema migrations
  static const int databaseVersion = 2;
  
  /// Default session ID when none is provided
  static const String defaultSessionId = '';

  // ========== SLIDER CONFIGURATION ==========
  /// Minimum slider value
  static const double sliderMin = 0.0;
  
  /// Maximum slider value
  static const double sliderMax = 100.0;
  
  /// Default slider value
  static const double sliderDefault = 0.0;
  
  /// Number of slider divisions
  static const int sliderDivisions = 100;
  
  /// Slider card width
  static const double sliderWidth = 300.0;
  
  /// Slider card height
  static const double sliderHeight = 28.0;

  // ========== ANIMATION ==========
  /// Standard animation duration
  static const Duration standardAnimationDuration = Duration(milliseconds: 300);
  
  /// Fast animation duration
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);

  // ========== TEXT STYLES ==========
  /// Standard text style for labels
  static const TextStyle labelTextStyle = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
  );
  
  /// Title text style
  static const TextStyle titleTextStyle = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.bold,
  );
}

/// Extension to provide easy access to common theme elements
extension AppTheme on ThemeData {
  /// Get the standard card theme used throughout the app
  CardTheme get standardCardTheme => CardTheme(
    elevation: AppConstants.standardElevation,
    color: AppConstants.cardBackgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppConstants.standardBorderRadius),
    ),
  );
}
