import 'package:flutter/material.dart';

/// Vytal Tek brand palette — shared across Light and Dark.
///
/// Do not invent a separate visual identity per theme.
abstract final class VytalColors {
  // Brand accents
  static const teal = Color(0xFF00D4C8);
  static const cyan = Color(0xFF00F2EA);
  static const green = Color(0xFF00E88A);
  static const violet = Color(0xFF9B6BFF);

  // Semantic
  static const caution = Color(0xFFFFB020);
  static const alert = Color(0xFFFF5A5A);
  static const info = Color(0xFF4DA3FF);

  // Dark surfaces (navy/charcoal, not pure black)
  static const darkCanvas = Color(0xFF0B0F16);
  static const darkSurface = Color(0xFF121826);
  static const darkElevated = Color(0xFF1A2233);
  static const darkBorder = Color(0xFF2A3347);
  static const darkTextPrimary = Color(0xFFF4F7FB);
  static const darkTextSecondary = Color(0xFFA8B3C7);
  static const darkTextMuted = Color(0xFF6F7B91);

  // Light surfaces (clean white / soft gray)
  static const lightCanvas = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFEEF2F7);
  static const lightBorder = Color(0xFFD7DEE8);
  static const lightTextPrimary = Color(0xFF0F1724);
  static const lightTextSecondary = Color(0xFF4A5568);
  static const lightTextMuted = Color(0xFF7A8699);
}
