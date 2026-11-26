import 'package:flutter/material.dart';

/// Design tokens and color palette inspired by Waitaki Boys' High School
/// heritage (Deep Navy, Old Gold & Crimson Crest) combined with modern LinkedIn-style UI.
class AppColors {
  // Primary WBHS Navy
  static const Color navyPrimary = Color(0xFF0F2547);
  static const Color navyDark = Color(0xFF0A1931);
  static const Color navyLight = Color(0xFF1E3A66);
  static const Color navyMuted = Color(0xFF334E77);

  // WBHS Heritage Gold & Brass Accents
  static const Color goldAccent = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB88E1F);
  static const Color goldLight = Color(0xFFF0DF87);

  // Crest Crimson Accent
  static const Color crimson = Color(0xFF8E1B24);
  static const Color crimsonLight = Color(0xFFC0392B);

  // Neutrals / Light Theme
  static const Color background = Color(0xFFF4F6F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDarker = Color(0xFFCBD5E1);

  // Neutrals / Dark Theme (Waitaki Deep Midnight Navy)
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF131D31);
  static const Color darkSurfaceMuted = Color(0xFF1B2842);
  static const Color darkBorder = Color(0xFF263552);
  static const Color darkBorderDarker = Color(0xFF364A70);

  // Light Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnNavy = Color(0xFFF8FAFC);

  // Dark Text & High-Contrast Accents
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextMuted = Color(0xFF94A3B8);
  static const Color darkAccent = Color(0xFF93C5FD);
  static const Color darkCrimson = Color(0xFFF87171);

  // Status & Feedback
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Interactive
  static const Color likeActive = Color(0xFFEF4444);
  static const Color likeInactive = Color(0xFF64748B);

  // Context-aware theme helpers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color card(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color cardMuted(BuildContext context) =>
      isDark(context) ? darkSurfaceMuted : surfaceMuted;

  static Color line(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color lineDarker(BuildContext context) =>
      isDark(context) ? darkBorderDarker : borderDarker;

  static Color heading(BuildContext context) =>
      isDark(context) ? darkTextPrimary : navyDark;

  static Color body(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color subtext(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color muted(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;

  static Color brand(BuildContext context) =>
      isDark(context) ? goldAccent : navyPrimary;

  static Color brandLink(BuildContext context) =>
      isDark(context) ? darkAccent : navyPrimary;

  static Color danger(BuildContext context) =>
      isDark(context) ? darkCrimson : crimson;
}
