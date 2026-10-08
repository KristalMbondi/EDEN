import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/trip.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Reçu d'une course (CdC §2.2 « reçu dans l'historique »).
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('receipt_title'))),
      body: tripAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (t) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _row(context, 'receipt_ref', t.id),
            _row(context, 'receipt_date', formatDateTime(t.createdAt)),
            _row(context, 'receipt_status', tripStatusLabel(context, t.status)),
            _row(context, 'receipt_from', t.pickup.label),
            _row(context, 'receipt_to', t.destination.label),
            _row(context, 'receipt_distance', formatKm(t.estimate.distanceKm)),
            _row(context, 'trip_estimated', formatXaf(t.estimate.price)),
            if (t.finalPrice != null) _row(context, 'receipt_final', formatXaf(t.finalPrice!)),
            if ((t.cancellationFee ?? 0) > 0) _row(context, 'receipt_cancel_fee', formatXaf(t.cancellationFee!)),
            if (t.paidWithEmergencyCredit) _row(context, 'receipt_payment', context.tr('receipt_emergency_credit')),
            if (t.driver != null) ...[
              _row(context, 'receipt_driver', t.driver!.name),
              _row(context, 'trip_plate', t.driver!.plate),
            ],
            if (t.rating != null) _row(context, 'receipt_rating', '${t.rating} / 5'),
            if (t.status == TripStatus.incident) ...[
              const SizedBox(height: 12),
              InfoBanner(text: context.tr('trip_incident')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String labelKey, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(context.tr(labelKey), style: Theme.of(context).textTheme.bodySmall)),
          Expanded(flex: 2, child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
