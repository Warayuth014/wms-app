import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================
// Theme Provider — ValueNotifier for dark/light
// =============================================
class ThemeProvider extends ValueNotifier<ThemeMode> {
  ThemeProvider() : super(ThemeMode.light);

  bool get isDark => value == ThemeMode.dark;

  void toggle() {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
  }

  void setMode(ThemeMode mode) => value = mode;
}

// Global instance
final themeProvider = ThemeProvider();

// =============================================
// AppTheme
// =============================================
class AppTheme {
  AppTheme._();

  // ── Brand Colors (shared) ─────────────────
  static const primary     = Color(0xFF1565C0);
  static const secondary   = Color(0xFF0288D1);
  static const teal        = Color(0xFF00838F);
  static const success     = Color(0xFF2E7D32);
  static const warning     = Color(0xFFF57F17);
  static const danger      = Color(0xFFC62828);
  static const purple      = Color(0xFF6A1B9A);

  // ── Light palette ─────────────────────────
  static const _lightBg         = Color(0xFFF5F7FA);
  static const _lightSurface    = Color(0xFFFFFFFF);
  static const _lightCard       = Color(0xFFFFFFFF);
  static const _lightTextPrimary = Color(0xFF1A1A2E);
  static const _lightTextGrey   = Color(0xFF6B7280);
  static const _lightBorder     = Color(0xFFE5E7EB);
  static const _lightDivider    = Color(0xFFF3F4F6);

  // ── Dark palette ──────────────────────────
  static const _darkBg          = Color(0xFF0F1117);
  static const _darkSurface     = Color(0xFF1A1D27);
  static const _darkCard        = Color(0xFF1E2230);
  static const _darkTextPrimary = Color(0xFFF1F3F5);
  static const _darkTextGrey    = Color(0xFF9CA3AF);
  static const _darkBorder      = Color(0xFF2D3142);
  static const _darkDivider     = Color(0xFF252836);

  // ── Semantic getters (theme-aware) ────────
  // Use these inside build methods:
  //   AppTheme.textPrimary(context)
  static Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color card(BuildContext context) =>
      Theme.of(context).cardColor;
  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? _darkTextPrimary : _lightTextPrimary;
  static Color textGrey(BuildContext context) =>
      _isDark(context) ? _darkTextGrey : _lightTextGrey;
  static Color border(BuildContext context) =>
      _isDark(context) ? _darkBorder : _lightBorder;
  static Color divider(BuildContext context) =>
      _isDark(context) ? _darkDivider : _lightDivider;
  static Color inputFill(BuildContext context) =>
      _isDark(context) ? _darkSurface : _lightSurface;
  static Color shimmer(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2A2D3A) : const Color(0xFFE8EAF0);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ── Backwards-compat static colors ────────
  // (used by screens that don't have context yet)
  static const textPrimaryColor = _lightTextPrimary;
  static const textGreyColor    = _lightTextGrey;
  static const borderColor      = _lightBorder;

  // ── Shared constants ──────────────────────
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  static const double touchTarget = 48;

  // ── Light Theme ───────────────────────────
  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: _lightSurface,
    );

    return _build(
      colorScheme: cs,
      scaffoldBg: _lightBg,
      cardColor: _lightCard,
      textPrimary: _lightTextPrimary,
      textGrey: _lightTextGrey,
      borderColor: _lightBorder,
      dividerColor: _lightDivider,
      inputFill: _lightSurface,
      brightness: Brightness.light,
    );
  }

  // ── Dark Theme ────────────────────────────
  static ThemeData get dark {
    final cs = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: _darkSurface,
    );

    return _build(
      colorScheme: cs,
      scaffoldBg: _darkBg,
      cardColor: _darkCard,
      textPrimary: _darkTextPrimary,
      textGrey: _darkTextGrey,
      borderColor: _darkBorder,
      dividerColor: _darkDivider,
      inputFill: _darkCard,
      brightness: Brightness.dark,
    );
  }

  // ── Builder ───────────────────────────────
  static ThemeData _build({
    required ColorScheme colorScheme,
    required Color scaffoldBg,
    required Color cardColor,
    required Color textPrimary,
    required Color textGrey,
    required Color borderColor,
    required Color dividerColor,
    required Color inputFill,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Sarabun',
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardColor,
      dividerColor: dividerColor,

      // ── AppBar ──────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? _darkSurface : primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          fontFamily: 'Sarabun',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),

      // ── Card ────────────────────────────
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isDark ? 0 : 1,
        shadowColor: isDark ? Colors.transparent : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: isDark
              ? BorderSide(color: borderColor, width: 1)
              : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),

      // ── ElevatedButton ──────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark
              ? const Color(0xFF2A2D3A)
              : const Color(0xFFBDBDBD),
          minimumSize: const Size(double.infinity, touchTarget + 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          elevation: isDark ? 0 : 2,
          shadowColor: primary.withValues(alpha: 0.3),
          textStyle: const TextStyle(
            fontFamily: 'Sarabun',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── OutlinedButton ──────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, touchTarget + 4),
          side: BorderSide(color: primary.withValues(alpha: isDark ? 0.5 : 1), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Sarabun',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── TextButton ─────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(touchTarget, touchTarget),
          textStyle: const TextStyle(
            fontFamily: 'Sarabun',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── InputDecoration ─────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(
          color: textGrey,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: textGrey.withValues(alpha: 0.6),
          fontSize: 14,
        ),
      ),

      // ── Divider ─────────────────────────
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      // ── BottomSheet ─────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? _darkCard : _lightCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
        elevation: isDark ? 0 : 8,
      ),

      // ── Dialog ──────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? _darkCard : _lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        elevation: isDark ? 0 : 8,
      ),

      // ── TabBar ──────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: textGrey,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontFamily: 'Sarabun',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Sarabun',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),

      // ── Snackbar ────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        elevation: isDark ? 0 : 4,
      ),

      // ── Chip ────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? _darkSurface : const Color(0xFFF3F4F6),
        labelStyle: TextStyle(
          fontFamily: 'Sarabun',
          fontSize: 12,
          color: textGrey,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXs),
        ),
        side: BorderSide.none,
      ),

      // ── ProgressIndicator ───────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
      ),
    );
  }
}
