import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const accent = Color(0xFF0E8A5F);
  static const accentLight = Color(0xFF22C58B);
  static const accentDark = Color(0xFF0B6B4A);

  // Light
  static const lightBg = Color(0xFFF6FAF8);
  static const lightSurface = Colors.white;
  static const lightBorder = Color(0xFFE0EBE5);
  static const lightText = Color(0xFF0F1F19);
  static const lightMuted = Color(0xFF5E7068);

  // Dark
  static const darkBg = Color(0xFF07110D);
  static const darkSurface = Color(0xFF0F1D17);
  static const darkBorder = Color(0xFF1E3029);
  static const darkText = Color(0xFFE6F2EC);
  static const darkMuted = Color(0xFF89A297);

  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFD97706);
}

/// Semantic tokens that aren't part of [ColorScheme].
class Tokens extends ThemeExtension<Tokens> {
  const Tokens({
    required this.muted,
    required this.border,
    required this.accentSoft,
  });

  final Color muted;
  final Color border;
  final Color accentSoft;

  @override
  Tokens copyWith({Color? muted, Color? border, Color? accentSoft}) => Tokens(
        muted: muted ?? this.muted,
        border: border ?? this.border,
        accentSoft: accentSoft ?? this.accentSoft,
      );

  @override
  Tokens lerp(Tokens? other, double t) {
    if (other == null) return this;
    return Tokens(
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
    );
  }
}

extension ThemeX on BuildContext {
  Tokens get tokens => Theme.of(this).extension<Tokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

TextStyle arabicStyle({double size = 26, Color? color, double height = 2.0}) =>
    GoogleFonts.amiri(fontSize: size, color: color, height: height);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final bg = dark ? AppColors.darkBg : AppColors.lightBg;
  final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
  final border = dark ? AppColors.darkBorder : AppColors.lightBorder;
  final fg = dark ? AppColors.darkText : AppColors.lightText;
  final muted = dark ? AppColors.darkMuted : AppColors.lightMuted;
  final accent = dark ? AppColors.accentLight : AppColors.accent;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: Colors.white,
    secondary: accent,
    onSecondary: Colors.white,
    error: AppColors.danger,
    onError: Colors.white,
    surface: surface,
    onSurface: fg,
    surfaceContainerLowest: bg,
    surfaceContainerLow: bg,
    surfaceContainer: surface,
    surfaceContainerHigh: surface,
    surfaceContainerHighest: dark ? const Color(0xFF152720) : const Color(0xFFEDF5F0),
    outline: border,
    outlineVariant: border,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    splashFactory: InkSparkle.splashFactory,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: fg,
    displayColor: fg,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: textTheme.bodySmall?.copyWith(color: muted),
    ),
    extensions: [
      Tokens(
        muted: muted,
        border: border,
        accentSoft: accent.withValues(alpha: dark ? 0.16 : 0.08),
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: fg,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 20),
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: accent.withValues(alpha: dark ? 0.2 : 0.1),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? accent : muted, size: 24),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : (dark ? muted : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accent : border,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: muted),
      prefixIconColor: muted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: accent.withValues(alpha: dark ? 0.2 : 0.1),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 13),
      showCheckmark: false,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
