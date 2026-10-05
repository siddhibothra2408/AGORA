import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'agora_colors.dart';

/// Agora Typography System
///
/// Features a distinguished classical serif for major headings (Lora)
/// and a crisp, modern sans-serif for interface and body (Inter).
abstract final class AgoraTypography {
  // Display & Headline Font: Classical Serif (Lora)
  static TextStyle get displayLarge => GoogleFonts.lora(
    fontSize: 32.0,
    fontWeight: FontWeight.w700,
    color: AgoraColors.navyDark,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static TextStyle get displayMedium => GoogleFonts.lora(
    fontSize: 26.0,
    fontWeight: FontWeight.w600,
    color: AgoraColors.navyDark,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static TextStyle get headlineLarge => GoogleFonts.lora(
    fontSize: 22.0,
    fontWeight: FontWeight.w600,
    color: AgoraColors.navyDark,
    height: 1.35,
  );

  static TextStyle get headlineMedium => GoogleFonts.lora(
    fontSize: 19.0,
    fontWeight: FontWeight.w600,
    color: AgoraColors.navy,
    height: 1.4,
  );

  // Interface & Body Font: Crisp Sans-Serif (Inter)
  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 17.0,
    fontWeight: FontWeight.w600,
    color: AgoraColors.navyDark,
    height: 1.4,
  );

  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    color: AgoraColors.navy,
    height: 1.45,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    color: AgoraColors.navy,
    height: 1.55,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: AgoraColors.navyMuted,
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    color: AgoraColors.navySubtle,
    height: 1.4,
  );

  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    color: AgoraColors.navyDark,
    letterSpacing: 0.1,
  );

  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    color: AgoraColors.navyMuted,
    letterSpacing: 0.2,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 11.0,
    fontWeight: FontWeight.w500,
    color: AgoraColors.navySubtle,
    letterSpacing: 0.3,
  );

  // Special badge/gold typography
  static TextStyle get aiBadge => GoogleFonts.inter(
    fontSize: 11.0,
    fontWeight: FontWeight.w700,
    color: AgoraColors.goldDark,
    letterSpacing: 0.5,
  );
}
