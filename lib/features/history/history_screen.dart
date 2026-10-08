import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/trip.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Historique des courses (CdC §1.2) + réservations à venir.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    final eden = context.eden;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('history_title'))),
      body: historyAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (trips) {
          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const IconBubble(icon: Icons.receipt_long_rounded, size: 72),
                  const SizedBox(height: 16),
                  Text(context.tr('history_empty'), style: TextStyle(color: eden.muted)),
                ],
              ),
            );
          }
          final upcoming = trips.where((t) => t.status == TripStatus.scheduled).toList();
          final others = trips.where((t) => t.status != TripStatus.scheduled).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (upcoming.isNotEmpty) ...[
                SectionTitle(context.tr('history_upcoming')),
                for (final t in upcoming) ...[_TripTile(trip: t), const SizedBox(height: 8)],
                const SizedBox(height: 16),
              ],
              if (others.isNotEmpty) ...[
                SectionTitle(context.tr('history_past')),
                for (final t in others) ...[_TripTile(trip: t), const SizedBox(height: 8)],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    final t = trip;
    final amount = t.finalPrice ?? t.cancellationFee;
    final Color statusColor;
    switch (t.status) {
      case TripStatus.completed:
        statusColor = AppColors.accent;
      case TripStatus.scheduled:
      case TripStatus.searching:
      case TripStatus.driverAssigned:
      case TripStatus.driverArrived:
      case TripStatus.inProgress:
        statusColor = AppColors.primary;
      case TripStatus.incident:
        statusColor = AppColors.warning;
      default:
        statusColor = eden.muted;
    }
    final when = t.scheduledAt != null ? formatDayTime(context, t.scheduledAt!) : formatDateTime(t.createdAt);
    return EdenCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.push(
        t.status.isActive
            ? (t.status == TripStatus.searching ? '/searching/${t.id}' : '/trip/${t.id}')
            : '/history/${t.id}',
      ),
      child: Row(
        children: [
          IconBubble(icon: categoryIcon(t.category), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('$when · ${categoryLabel(context, t.category)}',
                    style: TextStyle(color: eden.muted, fontSize: 12.5)),
                const SizedBox(height: 6),
                StatusPill(text: tripStatusLabel(context, t.status), color: statusColor),
              ],
            ),
          ),
          if (amount != null)
            Text(formatXaf(amount), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
