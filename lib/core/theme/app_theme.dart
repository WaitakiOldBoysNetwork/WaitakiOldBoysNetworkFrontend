import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  static const String fontFamily = 'Inter';
  static const List<String> fontFamilyFallback = [
    'Roboto',
    'Segoe UI',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static TextTheme _buildTextTheme({
    required Color headingColor,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w700,
        color: headingColor,
        letterSpacing: -0.2,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w700,
        color: headingColor,
        letterSpacing: -0.1,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w700,
        color: primaryColor,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        color: primaryColor,
        fontSize: 15,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        color: secondaryColor,
        fontSize: 14,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.0,
      ),
    );
  }

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme(
      headingColor: AppColors.navyDark,
      primaryColor: AppColors.textPrimary,
      secondaryColor: AppColors.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.navyPrimary,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.navyPrimary,
        secondary: AppColors.goldAccent,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.textOnNavy,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.navyDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.navyDark),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.navyPrimary,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navyPrimary,
          side: const BorderSide(color: AppColors.navyPrimary, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navyPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.navyPrimary.withValues(alpha: 0.12),
        elevation: 2,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.navyPrimary,
            );
          }
          return const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.navyPrimary, size: 24);
          }
          return const IconThemeData(color: AppColors.textSecondary, size: 24);
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = _buildTextTheme(
      headingColor: AppColors.darkTextPrimary,
      primaryColor: AppColors.darkTextPrimary,
      secondaryColor: AppColors.darkTextSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.goldAccent,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.goldAccent,
        secondary: AppColors.darkAccent,
        surface: AppColors.darkSurface,
        error: AppColors.darkCrimson,
        onPrimary: AppColors.navyDark,
        onSurface: AppColors.darkTextPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
        hintStyle: const TextStyle(color: AppColors.darkTextMuted, fontSize: 14),
        prefixIconColor: AppColors.darkTextSecondary,
        suffixIconColor: AppColors.darkTextSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.goldAccent,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.darkCrimson, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyLight,
          foregroundColor: AppColors.darkTextPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkAccent,
          side: const BorderSide(color: AppColors.darkBorderDarker, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkAccent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceMuted,
        selectedColor: AppColors.goldAccent.withValues(alpha: 0.2),
        side: const BorderSide(color: AppColors.darkBorder),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.darkTextPrimary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.navyDark;
          }
          return AppColors.darkTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.goldAccent;
          }
          return AppColors.darkBorderDarker;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.goldAccent.withValues(alpha: 0.16),
        elevation: 2,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.goldAccent,
            );
          }
          return const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.goldAccent, size: 24);
          }
          return const IconThemeData(
            color: AppColors.darkTextSecondary,
            size: 24,
          );
        }),
      ),
    );
  }
}
