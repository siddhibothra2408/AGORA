import 'package:flutter/material.dart';

import 'agora_colors.dart';
import 'agora_radius.dart';
import 'agora_spacing.dart';
import 'agora_typography.dart';

/// Agora Theme Builder
abstract final class AgoraTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AgoraColors.surfaceDim,
      canvasColor: AgoraColors.surface,
      cardColor: AgoraColors.surface,
      dividerColor: AgoraColors.surfaceBorder,

      // Color scheme
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AgoraColors.aegean,
        onPrimary: Colors.white,
        primaryContainer: AgoraColors.aegeanContainer,
        onPrimaryContainer: AgoraColors.aegeanDark,
        secondary: AgoraColors.navy,
        onSecondary: Colors.white,
        secondaryContainer: AgoraColors.surfaceContainer,
        onSecondaryContainer: AgoraColors.navyDark,
        tertiary: AgoraColors.gold,
        onTertiary: Colors.white,
        tertiaryContainer: AgoraColors.goldContainer,
        onTertiaryContainer: AgoraColors.goldDark,
        error: AgoraColors.error,
        onError: Colors.white,
        errorContainer: AgoraColors.errorContainer,
        onErrorContainer: AgoraColors.error,
        surface: AgoraColors.surface,
        onSurface: AgoraColors.navyDark,
        surfaceContainerHighest: AgoraColors.surfaceContainer,
        outline: AgoraColors.surfaceBorder,
        outlineVariant: AgoraColors.surfaceBorderSubtle,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AgoraTypography.displayLarge,
        displayMedium: AgoraTypography.displayMedium,
        headlineLarge: AgoraTypography.headlineLarge,
        headlineMedium: AgoraTypography.headlineMedium,
        titleLarge: AgoraTypography.titleLarge,
        titleMedium: AgoraTypography.titleMedium,
        bodyLarge: AgoraTypography.bodyLarge,
        bodyMedium: AgoraTypography.bodyMedium,
        bodySmall: AgoraTypography.bodySmall,
        labelLarge: AgoraTypography.labelLarge,
        labelMedium: AgoraTypography.labelMedium,
        labelSmall: AgoraTypography.labelSmall,
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: AgoraColors.surface,
        foregroundColor: AgoraColors.navyDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AgoraTypography.headlineLarge.copyWith(
          fontSize: 20.0,
          color: AgoraColors.navyDark,
        ),
        iconTheme: const IconThemeData(color: AgoraColors.navy, size: 22),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AgoraColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AgoraRadius.borderMd,
          side: const BorderSide(color: AgoraColors.surfaceBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AgoraColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AgoraSpacing.md,
          vertical: AgoraSpacing.sm + 2,
        ),
        hintStyle: AgoraTypography.bodyMedium.copyWith(
          color: AgoraColors.navyDisabled,
        ),
        labelStyle: AgoraTypography.bodyMedium.copyWith(
          color: AgoraColors.navyMuted,
        ),
        border: OutlineInputBorder(
          borderRadius: AgoraRadius.borderMd,
          borderSide: const BorderSide(color: AgoraColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AgoraRadius.borderMd,
          borderSide: const BorderSide(color: AgoraColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AgoraRadius.borderMd,
          borderSide: const BorderSide(color: AgoraColors.aegean, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AgoraRadius.borderMd,
          borderSide: const BorderSide(color: AgoraColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AgoraRadius.borderMd,
          borderSide: const BorderSide(color: AgoraColors.error, width: 1.5),
        ),
      ),

      // Buttons with 48dp touch target
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, AgoraSpacing.minTouchTarget),
          elevation: 0,
          backgroundColor: AgoraColors.aegean,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AgoraRadius.borderMd),
          textStyle: AgoraTypography.labelLarge.copyWith(color: Colors.white),
          padding: const EdgeInsets.symmetric(
            horizontal: AgoraSpacing.lg,
            vertical: AgoraSpacing.sm,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, AgoraSpacing.minTouchTarget),
          foregroundColor: AgoraColors.aegean,
          side: const BorderSide(color: AgoraColors.surfaceBorder, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: AgoraRadius.borderMd),
          textStyle: AgoraTypography.labelLarge.copyWith(
            color: AgoraColors.aegean,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AgoraSpacing.lg,
            vertical: AgoraSpacing.sm,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AgoraSpacing.minTouchTarget),
          foregroundColor: AgoraColors.aegean,
          shape: RoundedRectangleBorder(borderRadius: AgoraRadius.borderSm),
          textStyle: AgoraTypography.labelLarge.copyWith(
            color: AgoraColors.aegean,
          ),
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AgoraColors.surface,
        selectedItemColor: AgoraColors.aegean,
        unselectedItemColor: AgoraColors.navySubtle,
        elevation: 4,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AgoraColors.surfaceBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
