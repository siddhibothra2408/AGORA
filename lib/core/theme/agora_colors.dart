import 'package:flutter/material.dart';

/// Agora Design System Color Palette
///
/// Principles:
/// - Whitewashed, calm surfaces (not harsh pure-white everywhere, but clean alabaster).
/// - Deep navy text for superior contrast and dignified readability.
/// - Aegean blue for primary interface elements, active states, and controls.
/// - Gold strictly reserved for AI-related elements (provenance, proposals, audit).
/// - Restrained warnings and errors (no neon alerts).
abstract final class AgoraColors {
  // Surfaces
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF8F9FA);
  static const Color surfaceContainer = Color(0xFFF1F4F7);
  static const Color surfaceContainerHigh = Color(0xFFE8ECEF);
  static const Color surfaceBorder = Color(0xFFE2E8F0);
  static const Color surfaceBorderSubtle = Color(0xFFEDF2F7);

  // Deep Navy Typography
  static const Color navyDark = Color(0xFF0B192C);
  static const Color navy = Color(0xFF1E293B);
  static const Color navyMuted = Color(0xFF475569);
  static const Color navySubtle = Color(0xFF64748B);
  static const Color navyDisabled = Color(0xFF94A3B8);

  // Aegean Blue (Standard Interactive Elements)
  static const Color aegean = Color(0xFF1A5276);
  static const Color aegeanDark = Color(0xFF154360);
  static const Color aegeanLight = Color(0xFF2980B9);
  static const Color aegeanContainer = Color(0xFFEBF5FB);
  static const Color aegeanContainerBorder = Color(0xFFD4E6F1);

  // Agora Gold (STRICTLY RESERVED FOR AI ELEMENTS)
  // Used only for: AI handoffs, proposals, provenance links, AI audit indicators.
  static const Color gold = Color(0xFFC69214);
  static const Color goldBright = Color(0xFFE5A93C);
  static const Color goldDark = Color(0xFF8C6F12);
  static const Color goldContainer = Color(0xFFFEF9E7);
  static const Color goldContainerBorder = Color(0xFFFAD7A0);

  // Restrained Status Colors
  static const Color success = Color(0xFF1E7E34);
  static const Color successContainer = Color(0xFFEAF5EC);
  static const Color successBorder = Color(0xFFC3E6CB);

  static const Color error = Color(0xFFA93226);
  static const Color errorContainer = Color(0xFFFADBD8);
  static const Color errorBorder = Color(0xFFF5B7B1);

  static const Color warning = Color(0xFFB9770E);
  static const Color warningContainer = Color(0xFFFCF3CF);
  static const Color warningBorder = Color(0xFFF9E79F);

  // Withhold Status (Author Consent Shield)
  static const Color withhold = Color(0xFF6C3483);
  static const Color withholdContainer = Color(0xFFF4ECF7);
  static const Color withholdBorder = Color(0xFFD7BDE2);

  // Terracotta (Overdue indicator, non-alarmist warm ceramic tone)
  static const Color terracotta = Color(0xFFC85A32);
  static const Color terracottaContainer = Color(0xFFF9ECE6);
  static const Color terracottaBorder = Color(0xFFE8B4A2);
}
