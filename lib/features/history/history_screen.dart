import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/trip.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Historique des courses (CdC §1.2) ; chaque course ouvre son reçu.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('history_title'))),
      body: historyAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (trips) {
          if (trips.isEmpty) {
            return Center(child: Text(context.tr('history_empty')));
          }
          return ListView.separated(
            itemCount: trips.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = trips[i];
              final amount = t.finalPrice ?? t.cancellationFee;
              return ListTile(
                leading: Icon(t.status == TripStatus.completed ? Icons.check_circle_outline : Icons.history),
                title: Text(t.destination.label),
                subtitle: Text('${formatDateTime(t.createdAt)} · ${tripStatusLabel(context, t.status)}'),
                trailing: amount == null ? null : Text(formatXaf(amount)),
                onTap: () => context.push(
                  t.status.isActive
                      ? (t.status == TripStatus.searching ? '/searching/${t.id}' : '/trip/${t.id}')
                      : '/history/${t.id}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
