import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/errors.dart';
import '../../domain/models/favorite_place.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/vehicle_category.dart';
import '../../domain/models/wallet.dart';
import '../../domain/models/wallet_transaction.dart';
import '../../domain/rules/wallet_check.dart';

/// Message d'erreur traduit à partir de n'importe quelle exception.
String errorMessage(BuildContext context, Object error) {
  if (error is AppException) return context.tr(error.code);
  return context.tr('err_generic');
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMessage(context, error))),
  );
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String tripStatusLabel(BuildContext context, TripStatus s) => context.tr('status_${s.name}');

String refusalLabel(BuildContext context, RefusalReason r) => context.tr('refusal_${r.name}');

String creditStatusLabel(BuildContext context, EmergencyCreditStatus s) =>
    context.tr('credit_${s.name}');

String transactionLabel(BuildContext context, TransactionType t) => context.tr('tx_${t.name}');

String operatorLabel(BuildContext context, MobileMoneyOperator o) => context.tr('op_${o.name}');

String categoryLabel(BuildContext context, VehicleCategory c) => context.tr('cat_${c.name}');

String favoriteLabel(BuildContext context, FavoritePlace f) =>
    f.kind == FavoriteKind.custom ? (f.customName ?? '') : context.tr('fav_${f.kind.name}');

IconData favoriteIcon(FavoriteKind k) {
  switch (k) {
    case FavoriteKind.home:
      return Icons.home_rounded;
    case FavoriteKind.work:
      return Icons.work_rounded;
    case FavoriteKind.custom:
      return Icons.star_rounded;
  }
}

/// "14:30"
String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "Aujourd'hui 14:30" / "Demain 08:15" / "10/10 14:30".
String formatDayTime(BuildContext context, DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final String dayLabel;
  if (diff == 0) {
    dayLabel = context.tr('day_today');
  } else if (diff == 1) {
    dayLabel = context.tr('day_tomorrow');
  } else {
    dayLabel = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
  return '$dayLabel ${formatTime(d)}';
}

/// Écran de chargement / erreur générique.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(errorMessage(context, error), textAlign: TextAlign.center),
        ),
      );
}

/// Bandeau d'information coloré.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text, this.color, this.icon = Icons.info_outline});

  final String text;
  final Color? color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.4))),
        ],
      ),
    );
  }
}
