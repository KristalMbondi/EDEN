import 'package:flutter/material.dart';

import '../../domain/models/vehicle_category.dart';
import '../theme/app_theme.dart';

/// Carte arrondie de base (style « cartes blanches » de la maquette 1).
class EdenCard extends StatelessWidget {
  const EdenCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.selected = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppTheme.radius);
    return Container(
      decoration: BoxDecoration(
        color: color ?? eden.surface,
        borderRadius: radius,
        border: Border.all(
          color: selected ? AppColors.primary : eden.border,
          width: selected ? 2 : 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF10202B).withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Fond en dégradé doux aux teintes du logo (en-têtes, écrans d'accueil).
class SoftGradient extends StatelessWidget {
  const SoftGradient({super.key, required this.child, this.borderRadius});

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [eden.gradientStart, eden.gradientEnd],
        ),
      ),
      child: child,
    );
  }
}

/// Panneau du bas posé sur la carte (choix de course, suivi…).
class BottomPanel extends StatelessWidget {
  const BottomPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: eden.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: eden.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Titre de section.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Pastille ronde avec une icône sur fond teinté.
class IconBubble extends StatelessWidget {
  const IconBubble({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.background,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? context.eden.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Avatar avec l'initiale du prénom (ou une icône si pas de prénom).
class AvatarInitial extends StatelessWidget {
  const AvatarInitial({super.key, this.name, this.size = 44});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final n = name?.trim() ?? '';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
      ),
      child: n.isEmpty
          ? Icon(Icons.person, color: Colors.white, size: size * 0.55)
          : Text(
              n.characters.first.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: size * 0.42,
              ),
            ),
    );
  }
}

/// Pastille de statut (« Chauffeur en route », « Réservée »…).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text, this.color = AppColors.primary, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Icône simple par gamme (décision du 08/10/2026 : pas d'image de véhicule).
IconData categoryIcon(VehicleCategory c) {
  switch (c) {
    case VehicleCategory.eco:
      return Icons.directions_car_outlined;
    case VehicleCategory.confort:
      return Icons.directions_car_filled;
  }
}

/// Petit indicateur de pages (écrans d'introduction).
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? AppColors.primary : context.eden.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
