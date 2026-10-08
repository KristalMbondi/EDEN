import 'package:flutter/material.dart';

/// Couleurs relevées sur le logo de l'application (dégradé bleu → vert).
/// Aucune charte graphique n'est définie dans le CdC : à remplacer par les
/// codes couleur officiels s'ils existent.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1582C3); // bleu du logo
  static const accent = Color(0xFF43B381); // vert de la feuille
  static const sos = Color(0xFFD32F2F);
  static const warning = Color(0xFFF9A825);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(centerTitle: false),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
