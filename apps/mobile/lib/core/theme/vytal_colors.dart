import 'package:flutter/material.dart';

/// Vytal Tek brand palette — shared across Light and Dark.
///
/// Dark mode is a true-black fitness OS: charcoal elevation, white type,
/// teal/cyan only where they carry meaning. Do not flood canvases with green.
abstract final class VytalColors {
  // Brand accents — used for primary actions, live health, and status only
  static const teal = Color(0xFF00E0D0);
  static const cyan = Color(0xFF00C6B8);
  static const green = Color(0xFF3DDC97);
  static const violet = Color(0xFF8B7CFF);

  // Semantic
  static const caution = Color(0xFFFFB020);
  static const alert = Color(0xFFFF5A5A);
  static const info = Color(0xFF4DA3FF);

  // Dark surfaces — true black canvas, charcoal elevation (not navy/teal mist)
  static const darkCanvas = Color(0xFF050505);
  static const darkSurface = Color(0xFF111111);
  static const darkElevated = Color(0xFF1A1A1A);
  static const darkBorder = Color(0xFF2C2C2C);
  static const darkTextPrimary = Color(0xFFF5F5F5);
  static const darkTextSecondary = Color(0xFFA3A3A3);
  static const darkTextMuted = Color(0xFF737373);

  // Light surfaces (same identity, quieter glow)
  static const lightCanvas = Color(0xFFF4F4F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFEEEEF0);
  static const lightBorder = Color(0xFFD4D4D8);
  static const lightTextPrimary = Color(0xFF111111);
  static const lightTextSecondary = Color(0xFF52525B);
  static const lightTextMuted = Color(0xFF71717A);
}
