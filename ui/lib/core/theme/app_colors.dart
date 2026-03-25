import 'package:flutter/material.dart';

/// Iron Orbit color palette from the Antinvestor design system.
/// Each color has a full tonal scale from T0 (darkest) to T100 (lightest).
class AppColors {
  AppColors._();

  // ── Primary: #0F172A ──────────────────────────────────────────────────
  static const Color primary = Color(0xFF0F172A);
  static const MaterialColor primarySwatch = MaterialColor(0xFF0F172A, {
    950: Color(0xFF000000), // T0
    900: Color(0xFF131B2E), // T10
    800: Color(0xFF283044), // T20
    700: Color(0xFF3F465C), // T30
    600: Color(0xFF565E74), // T40
    500: Color(0xFF6F778E), // T50
    400: Color(0xFF8990A8), // T60
    300: Color(0xFFA3ABC4), // T70
    200: Color(0xFFBEC6E0), // T80
    100: Color(0xFFDAE2FD), // T90
    50: Color(0xFFEEF0FF),  // T95
  });

  // ── Secondary: #475569 ────────────────────────────────────────────────
  static const Color secondary = Color(0xFF475569);
  static const MaterialColor secondarySwatch = MaterialColor(0xFF475569, {
    950: Color(0xFF000000),
    900: Color(0xFF0D1C2E),
    800: Color(0xFF233144),
    700: Color(0xFF3A485B),
    600: Color(0xFF515F74),
    500: Color(0xFF6A788D),
    400: Color(0xFF8392A8),
    300: Color(0xFF9EACC3),
    200: Color(0xFFB9C7DF),
    100: Color(0xFFD5E3FC),
    50: Color(0xFFEAF1FF),
  });

  // ── Tertiary / Accent: #0284C7 ───────────────────────────────────────
  static const Color tertiary = Color(0xFF0284C7);
  static const MaterialColor tertiarySwatch = MaterialColor(0xFF0284C7, {
    950: Color(0xFF000000),
    900: Color(0xFF001D31),
    800: Color(0xFF003351),
    700: Color(0xFF004B73),
    600: Color(0xFF006398),
    500: Color(0xFF007DBD),
    400: Color(0xFF3198DC),
    300: Color(0xFF54B3F8),
    200: Color(0xFF93CCFF),
    100: Color(0xFFCCE5FF),
    50: Color(0xFFE7F2FF),
  });

  // ── Neutral: #F8FAFC ─────────────────────────────────────────────────
  static const Color neutral = Color(0xFFF8FAFC);
  static const MaterialColor neutralSwatch = MaterialColor(0xFFF8FAFC, {
    950: Color(0xFF000000),
    900: Color(0xFF191C1E),
    800: Color(0xFF2D3133),
    700: Color(0xFF444749),
    600: Color(0xFF5C5F61),
    500: Color(0xFF747779),
    400: Color(0xFF8E9193),
    300: Color(0xFFA9ABAD),
    200: Color(0xFFC4C7C9),
    100: Color(0xFFE0E3E5),
    50: Color(0xFFEFF1F3),
  });

  // ── Semantic ──────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);

  // ── Surface shortcuts ─────────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF0F172A);
  static const Color onSurfaceMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE2E8F0);

  // ── Sidebar ───────────────────────────────────────────────────────────
  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarText = Color(0xFFCBD5E1);
  static const Color sidebarActiveText = Color(0xFFFFFFFF);
  static const Color sidebarActiveBg = Color(0xFF1E293B);
  static const Color sidebarHoverBg = Color(0xFF1E293B);
}
