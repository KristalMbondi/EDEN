import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/trip.dart';
import '../../domain/rules/pricing.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Fin de course (CdC §2.2) : débit au prix final réel, alerte si
/// dépassement > 30 %, notation 1 à 5 étoiles, reçu dans l'historique.
class TripEndScreen extends ConsumerStatefulWidget {
  const TripEndScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripEndScreen> createState() => _TripEndScreenState();
}

class _TripEndScreenState extends ConsumerState<TripEndScreen> {
  int _stars = 0;
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() => _sending = true);
    try {
      final comment = _comment.text.trim();
      await ref.read(tripRepositoryProvider).rateTrip(widget.tripId, _stars, comment.isEmpty ? null : comment);
      if (!mounted) return;
      showInfo(context, context.tr('end_thanks'));
      context.go('/home');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reportOverrun(Trip trip) async {
    await ref.read(tripRepositoryProvider).reportIssue(trip.id, 'fare_overrun');
    if (mounted) showInfo(context, context.tr('end_report_sent'));
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final rules = ref.watch(rulesConfigProvider).valueOrNull;
    final wallet = ref.watch(walletProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('end_title')), automaticallyImplyLeading: false),
      body: tripAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (trip) {
          final finalPrice = trip.finalPrice ?? trip.estimate.price;
          // Seuil de 30 % fixé par le CdC §2.2 (valeur servie par le backend).
          final alertPercent = rules?.pricing.overrunAlertPercent ?? 30;
          final overrun = isFareOverrun(
            estimatedPrice: trip.estimate.price,
            finalPrice: finalPrice,
            alertPercent: alertPercent,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Icon(Icons.check_circle, color: AppColors.primary, size: 64),
              const SizedBox(height: 8),
              Text(
                formatXaf(finalPrice),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                context.tr('end_debited'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${context.tr('trip_estimated')} : ${formatXaf(trip.estimate.price)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (overrun) ...[
                const SizedBox(height: 16),
                InfoBanner(
                  color: AppColors.warning,
                  icon: Icons.warning_amber_rounded,
                  text: context.tr('end_overrun_alert', {'percent': '$alertPercent'}),
                ),
                TextButton(onPressed: () => _reportOverrun(trip), child: Text(context.tr('end_report'))),
              ],
              if (wallet != null && wallet.isBlocked) ...[
                const SizedBox(height: 16),
                InfoBanner(
                  color: AppColors.sos,
                  icon: Icons.lock_outline,
                  text: context.tr('end_negative_balance', {'amount': formatXaf(wallet.balance)}),
                ),
              ],
              const SizedBox(height: 24),
              Text(context.tr('end_rate'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      iconSize: 40,
                      icon: Icon(i <= _stars ? Icons.star : Icons.star_border, color: AppColors.accent),
                      onPressed: () => setState(() => _stars = i),
                    ),
                ],
              ),
              TextField(
                controller: _comment,
                maxLines: 3,
                decoration: InputDecoration(labelText: context.tr('end_comment')),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (_stars == 0 || _sending) ? null : _submitRating,
                child: Text(context.tr('end_send_rating')),
              ),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(context.tr('end_skip')),
              ),
            ],
          );
        },
      ),
    );
  }
}
