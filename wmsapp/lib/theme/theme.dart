import 'package:flutter/material.dart';

class AppTheme {
  // ── Colors ──────────────────────────────────
  static const primary = Color(0xFF1565C0); // น้ำเงินเข้ม
  static const secondary = Color(0xFF0288D1); // น้ำเงินอ่อน
  static const success = Color(0xFF2E7D32); // เขียว
  static const warning = Color(0xFFF57F17); // เหลือง
  static const danger = Color(0xFFC62828); // แดง
  static const background = Color(0xFFF5F7FA); // พื้นหลัง
  static const surface = Color(0xFFFFFFFF); // card
  static const textPrimary = Color(0xFF1A1A2E); // ตัวอักษรหลัก
  static const textGrey = Color(0xFF6B7280); // ตัวอักษรรอง

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: 'Sarabun',
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: background,

    // ── AppBar ──────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Sarabun',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),

    // ── Card ────────────────────────────────
    cardTheme: CardThemeData(
      color: surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // ── ElevatedButton ──────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'Sarabun',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── OutlinedButton ──────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'Sarabun',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── InputDecoration ─────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
