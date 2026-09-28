import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'widgets/night.dart';

/// Night palette: deep navy sky, frosted glass cards, teal accents and lantern gold.
class AppColors {
  static const accent = Color(0xFF2B95A5); // buttons, toggles, active states
  static const accentLight = Color(0xFF22B8CC); // big numbers, highlights
  static const accentDark = Color(0xFF1C6E7B);
  static const gold = Color(0xFFE3BC6A);

  static const bg = Color(0xFF081421);
  static const bgTop = Color(0xFF10263A);
  static const raised = Color(0xFF0F2235); // opaque surface for sheets, dialogs, overlapping pills
  static const glass = Color(0x0FFFFFFF); // translucent card fill
  static const border = Color(0x24FFFFFF);
  static const text = Color(0xFFF2F6FA);
  static const muted = Color(0xFF93A5B6);

  static const danger = Color(0xFFF05252);
  static const warning = Color(0xFFF2A33A);
}

/// Semantic tokens that aren't part of [ColorScheme].
class Tokens extends ThemeExtension<Tokens> {
  const Tokens({
    required this.muted,
    required this.border,
    required this.accentSoft,
    required this.glass,
  });

  final Color muted;
  final Color border;
  final Color accentSoft;
  final Color glass;

  @override
  Tokens copyWith({Color? muted, Color? border, Color? accentSoft, Color? glass}) => Tokens(
        muted: muted ?? this.muted,
        border: border ?? this.border,
        accentSoft: accentSoft ?? this.accentSoft,
        glass: glass ?? this.glass,
      );

  @override
  Tokens lerp(Tokens? other, double t) {
    if (other == null) return this;
    return Tokens(
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
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

/// Mushaf-style script for Quran verses.
TextStyle quranStyle({double size = 28, Color? color, double height = 2.2}) =>
    GoogleFonts.amiriQuran(fontSize: size, color: color, height: height);

/// Headings use the same geometric sans as the body, a touch heavier.
TextStyle headingStyle(TextStyle? base) => GoogleFonts.outfit(textStyle: base);

/// Paints the night sky behind every page, so each route carries its own backdrop during transitions.
class _NightTransitions extends PageTransitionsBuilder {
  const _NightTransitions(this.inner);
  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> a, Animation<double> b, Widget child) =>
      inner.buildTransitions(route, context, a, b, Stack(fit: StackFit.expand, children: [const NightBackground(), child]));
}

/// The app has one look: the night theme. [brightness] is kept for API compatibility.
ThemeData buildTheme([Brightness brightness = Brightness.dark]) {
  const bg = AppColors.bg;
  const surface = AppColors.raised;
  const border = AppColors.border;
  const fg = AppColors.text;
  const muted = AppColors.muted;
  const accent = AppColors.accent;

  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: accent,
    onPrimary: Colors.white,
    secondary: AppColors.gold,
    onSecondary: Color(0xFF1A1206),
    error: AppColors.danger,
    onError: Colors.white,
    surface: surface,
    onSurface: fg,
    surfaceContainerLowest: bg,
    surfaceContainerLow: bg,
    surfaceContainer: surface,
    surfaceContainerHigh: surface,
    surfaceContainerHighest: Color(0x14FFFFFF),
    outline: border,
    outlineVariant: border,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: bg,
    splashFactory: InkSparkle.splashFactory,
  );

  final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).apply(bodyColor: fg, displayColor: fg);

  return base.copyWith(
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: textTheme.bodySmall?.copyWith(color: muted),
    ),
    extensions: [
      Tokens(
        muted: muted,
        border: border,
        accentSoft: accent.withValues(alpha: 0.18),
        glass: AppColors.glass,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: fg,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 20),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: AppColors.glass,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: border)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0x14FFFFFF), thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(
      iconColor: muted,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: accent.withValues(alpha: 0.2),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : const Color(0x26FFFFFF)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.glass,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: muted),
      labelStyle: const TextStyle(color: muted),
      prefixIconColor: muted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: accent, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0x1FFFFFFF),
        minimumSize: const Size(0, 50),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        minimumSize: const Size(0, 50),
        side: const BorderSide(color: Color(0x40FFFFFF)),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.accentLight)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.glass,
        foregroundColor: muted,
        selectedBackgroundColor: accent.withValues(alpha: 0.25),
        selectedForegroundColor: fg,
        side: const BorderSide(color: border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.glass,
      selectedColor: accent.withValues(alpha: 0.25),
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 13),
      showCheckmark: false,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0x40FFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: border)),
    ),
    datePickerTheme: const DatePickerThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1B3349),
      contentTextStyle: GoogleFonts.outfit(color: fg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _NightTransitions(FadeForwardsPageTransitionsBuilder()),
        TargetPlatform.iOS: _NightTransitions(CupertinoPageTransitionsBuilder()),
        TargetPlatform.linux: _NightTransitions(FadeForwardsPageTransitionsBuilder()),
        TargetPlatform.macOS: _NightTransitions(CupertinoPageTransitionsBuilder()),
        TargetPlatform.windows: _NightTransitions(FadeForwardsPageTransitionsBuilder()),
        TargetPlatform.fuchsia: _NightTransitions(FadeForwardsPageTransitionsBuilder()),
      },
    ),
  );
}
