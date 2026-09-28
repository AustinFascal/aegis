import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Theme Surfaces
  static const Color darkBackground = Color(0xFF090C12);
  static const Color darkSurface = Color(0xFF0F1522);
  static const Color darkSurfaceElevated = Color(0xFF161F32);
  static const Color darkCard = Color(0xFF182238);
  static const Color darkBorder = Color(0xFF22314E);
  static const Color darkBorderLight = Color(0xFF2C3E63);

  // Light Theme Surfaces
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderLight = Color(0xFFCBD5E1);

  // Backward-compatible aliases (defaults to dark theme defaults)
  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color surfaceElevated = darkSurfaceElevated;
  static const Color card = darkCard;
  static const Color border = darkBorder;
  static const Color borderLight = darkBorderLight;

  // Accents & Signals
  static const Color primary = Color(0xFF00E5FF);       // Cyber Cyan (Dark)
  static const Color primaryLight = Color(0xFF0284C7);  // Cyber Cobalt (Light)
  static const Color primaryDark = Color(0xFF00B0FF);
  static const Color success = Color(0xFF00E676);       // Emerald
  static const Color successLight = Color(0xFF16A34A);
  static const Color warning = Color(0xFFFFB300);       // Amber
  static const Color warningLight = Color(0xFFD97706);
  static const Color danger = Color(0xFFFF1744);        // Crimson
  static const Color dangerLight = Color(0xFFDC2626);
  static const Color info = Color(0xFF2979FF);          // Electric Blue
  static const Color purple = Color(0xFFD500F9);
  static const Color purpleLight = Color(0xFF9333EA);

  // Text
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Service Brands
  static const Color mysql = Color(0xFF00758F);
  static const Color ssh = Color(0xFF4E79A7);
  static const Color nginx = Color(0xFF009639);
}
