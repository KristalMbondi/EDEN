import 'package:flutter/material.dart';

/// Couleurs relevées sur le logo de l'application (dégradé bleu → vert).
/// Décision du 08/10/2026 : boutons principaux en BLEU uni, vert en accent.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1582C3); // bleu du logo
  static const accent = Color(0xFF43B381); // vert de la feuille
  static const sos = Color(0xFFD64545);
  static const warning = Color(0xFFE9A23B);
}

/// Jetons de couleur propres à l'application, en clair et en sombre.
@immutable
class EdenColors extends ThemeExtension<EdenColors> {
  const EdenColors({
    required this.background,
    required this.surface,
    required this.muted,
    required this.border,
    required this.gradientStart,
    required this.gradientEnd,
    required this.primarySoft,
    required this.accentSoft,
  });

  /// Fond des écrans.
  final Color background;

  /// Fond des cartes et panneaux.
  final Color surface;

  /// Texte secondaire.
  final Color muted;

  /// Bordures fines.
  final Color border;

  /// Dégradé doux (teintes du logo) pour les en-têtes.
  final Color gradientStart;
  final Color gradientEnd;

  /// Fonds teintés pour icônes et éléments sélectionnés.
  final Color primarySoft;
  final Color accentSoft;

  static const light = EdenColors(
    background: Color(0xFFF4F7FA),
    surface: Colors.white,
    muted: Color(0xFF6B7A86),
    border: Color(0xFFE3EAF0),
    gradientStart: Color(0xFFE3F0FA),
    gradientEnd: Color(0xFFE6F6EE),
    primarySoft: Color(0xFFE3F0FA),
    accentSoft: Color(0xFFE6F6EE),
  );

  static const dark = EdenColors(
    background: Color(0xFF0E1418),
    surface: Color(0xFF172128),
    muted: Color(0xFF93A3AE),
    border: Color(0xFF26333C),
    gradientStart: Color(0xFF12283A),
    gradientEnd: Color(0xFF12291F),
    primarySoft: Color(0xFF15344A),
    accentSoft: Color(0xFF173528),
  );

  @override
  EdenColors copyWith({
    Color? background,
    Color? surface,
    Color? muted,
    Color? border,
    Color? gradientStart,
    Color? gradientEnd,
    Color? primarySoft,
    Color? accentSoft,
  }) {
    return EdenColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      primarySoft: primarySoft ?? this.primarySoft,
      accentSoft: accentSoft ?? this.accentSoft,
    );
  }

  @override
  EdenColors lerp(ThemeExtension<EdenColors>? other, double t) {
    if (other is! EdenColors) return this;
    return EdenColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
    );
  }
}

extension EdenThemeX on BuildContext {
  EdenColors get eden => Theme.of(this).extension<EdenColors>() ?? EdenColors.light;
}

class AppTheme {
  AppTheme._();

  static const radius = 20.0;

  static ThemeData get light => _build(Brightness.light, EdenColors.light);
  static ThemeData get dark => _build(Brightness.dark, EdenColors.dark);

  static ThemeData _build(Brightness brightness, EdenColors eden) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: AppColors.sos,
      surface: eden.surface,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: eden.background,
      extensions: [eden],
    );
    final text = base.textTheme;
    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodySmall: text.bodySmall?.copyWith(color: eden.muted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: eden.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark ? const Color(0xFF26333C) : const Color(0xFFD5DEE5),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: eden.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: eden.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: eden.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: eden.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: eden.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: eden.primarySoft,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.primary : eden.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? AppColors.primary : eden.muted,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: eden.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: eden.surface,
        side: BorderSide(color: eden.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(fontFamily: 'Poppins', color: scheme.onSurface, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: eden.border, thickness: 1, space: 1),
    );
  }
}
