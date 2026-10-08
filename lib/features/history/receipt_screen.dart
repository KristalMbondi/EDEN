import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/trip.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Reçu d'une course (CdC §2.2 « reçu dans l'historique »), ou détail d'une
/// réservation à venir (avec annulation gratuite).
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  bool _cancelling = false;

  Future<void> _cancelReservation() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('reservation_cancel_title')),
        content: Text(context.tr('cancel_free')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel_keep'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.sos),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('cancel_confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(tripRepositoryProvider).cancelTrip(widget.tripId);
      if (mounted) showInfo(context, context.tr('reservation_cancelled'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('receipt_title'))),
      body: tripAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (t) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (t.lowBalanceWarning && t.status == TripStatus.scheduled) ...[
              InfoBanner(
                color: AppColors.warning,
                icon: Icons.warning_amber_rounded,
                text: context.tr('home_reservation_low_balance'),
              ),
              const SizedBox(height: 12),
            ],
            if (t.status == TripStatus.cancelledInsufficientBalance) ...[
              InfoBanner(
                color: AppColors.warning,
                icon: Icons.info_outline,
                text: context.tr('reservation_cancelled_balance'),
              ),
              const SizedBox(height: 12),
            ],
            EdenCard(
              child: Column(
                children: [
                  _row(context, 'receipt_ref', t.id),
                  _row(context, 'receipt_status', tripStatusLabel(context, t.status)),
                  if (t.scheduledAt != null)
                    _row(context, 'receipt_scheduled', formatDayTime(context, t.scheduledAt!))
                  else
                    _row(context, 'receipt_date', formatDateTime(t.createdAt)),
                  _row(context, 'receipt_category', categoryLabel(context, t.category)),
                  _row(context, 'receipt_from', t.pickup.label),
                  _row(context, 'receipt_to', t.destination.label),
                  _row(context, 'receipt_distance', formatKm(t.estimate.distanceKm)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            EdenCard(
              child: Column(
                children: [
                  _row(context, 'trip_estimated', formatXaf(t.estimate.price)),
                  if (t.finalPrice != null) _row(context, 'receipt_final', formatXaf(t.finalPrice!), bold: true),
                  if ((t.cancellationFee ?? 0) > 0)
                    _row(context, 'receipt_cancel_fee', formatXaf(t.cancellationFee!), bold: true),
                  _row(
                    context,
                    'receipt_payment',
                    context.tr(t.paidWithEmergencyCredit ? 'receipt_emergency_credit' : 'receipt_wallet'),
                  ),
                  if (t.driver != null) ...[
                    _row(context, 'receipt_driver', t.driver!.name),
                    _row(context, 'trip_plate', t.driver!.plate),
                  ],
                  if (t.rating != null) _row(context, 'receipt_rating', '${t.rating} / 5'),
                ],
              ),
            ),
            if (t.status == TripStatus.incident) ...[
              const SizedBox(height: 12),
              InfoBanner(text: context.tr('trip_incident')),
            ],
            if (t.status == TripStatus.scheduled) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.sos),
                onPressed: _cancelling ? null : _cancelReservation,
                child: Text(context.tr('reservation_cancel_title')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String labelKey, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(context.tr(labelKey), style: TextStyle(color: context.eden.muted, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
