import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../domain/errors.dart';
import '../../domain/models/trip.dart';
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
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
