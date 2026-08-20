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
    glowOpacity: 0.04,
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
    glowOpacity: 0.05,
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
      onPrimary: isDark ? Colors.black : Colors.white,
      secondary: isDark ? const Color(0xFF8A8A8A) : const Color(0xFF52525B),
      onSecondary: isDark ? Colors.black : Colors.white,
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
    final radius = BorderRadius.circular(14);

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
        backgroundColor: canvas.withValues(alpha: 0.94),
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: canvas,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: canvas,
              ),
        titleTextStyle: display.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: canvas,
        elevation: 0,
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
          foregroundColor: isDark ? Colors.black : Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VytalColors.teal,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border.withValues(alpha: 0.9)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevated,
        selectedColor: VytalColors.teal.withValues(alpha: glowOpacity + 0.08),
        labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return VytalColors.teal.withValues(alpha: glowOpacity + 0.08);
            }
            return elevated;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return VytalColors.teal;
            return textMuted;
          }),
          side: WidgetStateProperty.all(BorderSide(color: border)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated.withValues(alpha: isDark ? 0.7 : 1),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: textMuted),
        labelStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: VytalColors.teal),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: border.withValues(alpha: 0.85)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: VytalColors.teal, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: VytalColors.alert),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: elevated,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: border),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          elevation: const WidgetStatePropertyAll(8),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: textMuted.withValues(alpha: 0.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
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
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: VytalColors.teal,
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      extensions: <ThemeExtension<dynamic>>[
        VytalThemeExtras(
          canvas: canvas,
          elevated: elevated,
          border: border,
          textMuted: textMuted,
          glow: VytalColors.teal.withValues(alpha: glowOpacity),
          glassFill: surface.withValues(alpha: isDark ? 0.78 : 0.88),
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
