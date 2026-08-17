import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'vytal_colors.dart';

/// Builds Light and Dark Material themes from one brand system.
abstract final class VytalTheme {
  static ThemeData light() => _build(
    brightness: Brightness.light,
    canvas: VytalColors.lightCanvas,
    surface: VytalColors.lightSurface,
    elevated: VytalColors.lightElevated,
    border: VytalColors.lightBorder,
    textPrimary: VytalColors.lightTextPrimary,
    textSecondary: VytalColors.lightTextSecondary,
    textMuted: VytalColors.lightTextMuted,
    glowOpacity: 0.06,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    canvas: VytalColors.darkCanvas,
    surface: VytalColors.darkSurface,
    elevated: VytalColors.darkElevated,
    border: VytalColors.darkBorder,
    textPrimary: VytalColors.darkTextPrimary,
    textSecondary: VytalColors.darkTextSecondary,
    textMuted: VytalColors.darkTextMuted,
    glowOpacity: 0.11,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color canvas,
    required Color surface,
    required Color elevated,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required double glowOpacity,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: VytalColors.teal,
      onPrimary: isDark ? VytalColors.darkCanvas : Colors.white,
      secondary: VytalColors.green,
      onSecondary: isDark ? VytalColors.darkCanvas : Colors.white,
      tertiary: VytalColors.violet,
      onTertiary: Colors.white,
      error: VytalColors.alert,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: elevated,
      outline: border,
      outlineVariant: border.withValues(alpha: 0.7),
    );

    final baseText = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: textPrimary, displayColor: textPrimary);

    final display = GoogleFonts.soraTextTheme(baseText);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      cardColor: surface,
      dividerColor: border,
      textTheme: display.copyWith(
        headlineLarge: display.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineMedium: display.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: baseText.bodyMedium?.copyWith(color: textSecondary),
        bodySmall: baseText.bodySmall?.copyWith(color: textMuted),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas.withValues(alpha: 0.92),
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: display.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: VytalColors.teal.withValues(alpha: glowOpacity),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? VytalColors.teal : textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? VytalColors.teal : textMuted,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VytalColors.teal,
          foregroundColor: isDark ? VytalColors.darkCanvas : Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border.withValues(alpha: 0.85)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevated,
        selectedColor: VytalColors.teal.withValues(alpha: glowOpacity),
        labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      extensions: <ThemeExtension<dynamic>>[
        VytalThemeExtras(
          canvas: canvas,
          elevated: elevated,
          border: border,
          textMuted: textMuted,
          glow: VytalColors.cyan.withValues(alpha: glowOpacity),
          glassFill: surface.withValues(alpha: isDark ? 0.55 : 0.72),
        ),
      ],
    );
  }
}

@immutable
class VytalThemeExtras extends ThemeExtension<VytalThemeExtras> {
  const VytalThemeExtras({
    required this.canvas,
    required this.elevated,
    required this.border,
    required this.textMuted,
    required this.glow,
    required this.glassFill,
  });

  final Color canvas;
  final Color elevated;
  final Color border;
  final Color textMuted;
  final Color glow;
  final Color glassFill;

  @override
  VytalThemeExtras copyWith({
    Color? canvas,
    Color? elevated,
    Color? border,
    Color? textMuted,
    Color? glow,
    Color? glassFill,
  }) {
    return VytalThemeExtras(
      canvas: canvas ?? this.canvas,
      elevated: elevated ?? this.elevated,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
      glow: glow ?? this.glow,
      glassFill: glassFill ?? this.glassFill,
    );
  }

  @override
  VytalThemeExtras lerp(ThemeExtension<VytalThemeExtras>? other, double t) {
    if (other is! VytalThemeExtras) return this;
    return VytalThemeExtras(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
    );
  }
}

extension VytalThemeContext on BuildContext {
  VytalThemeExtras get vytalExtras =>
      Theme.of(this).extension<VytalThemeExtras>()!;
}
