import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF04143B);
  static const blueDark = Color(0xFF0066FF);
  static const blueLight = Color(0xFF00C2FF);
  static const greenLime = Color(0xFF8EF500);
  static const greenEmerald = Color(0xFF00B32C);
  static const greenInk = Color(0xFF008A22);
  static const page = Color(0xFFF5F8FD);
  static const danger = Color(0xFFD92D4A);

  static const blueGradient = LinearGradient(colors: [blueDark, blueLight]);
  static const greenGradient = LinearGradient(colors: [greenEmerald, greenLime]);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.blueDark).copyWith(
    primary: AppColors.blueDark,
    onSurface: AppColors.navy,
    error: AppColors.danger,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: AppColors.navy.withValues(alpha: 0.16)),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.page,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.navy,
      displayColor: AppColors.navy,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.blueDark, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
  );
}