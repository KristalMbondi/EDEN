import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/trip.dart';
import '../../domain/rules/pricing.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Fin de course (CdC §2.2), inspirée de l'écran « You arrived! » de la
/// maquette 2 (sans pourboire, décision du 08/10/2026) : débit au prix
/// final réel, alerte si dépassement > 30 %, note 1 à 5, reçu.
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
    final eden = context.eden;

    return Scaffold(
      body: tripAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (trip) {
          final finalPrice = trip.finalPrice ?? trip.estimate.price;
          // Seuil de 30 % fixé par le CdC §2.2 (valeur servie par le backend).
          final alertPercent = rules?.pricingFor(trip.category).overrunAlertPercent ?? 30;
          final overrun = isFareOverrun(
            estimatedPrice: trip.estimate.price,
            finalPrice: finalPrice,
            alertPercent: alertPercent,
          );
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              SoftGradient(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                    child: Column(
                      children: [
                        const IconBubble(
                          icon: Icons.check_rounded,
                          size: 72,
                          color: Colors.white,
                          background: AppColors.accent,
                        ),
                        const SizedBox(height: 16),
                        Text(context.tr('end_title'), style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(trip.destination.label, style: TextStyle(color: eden.muted)),
                        const SizedBox(height: 20),
                        Text(formatXaf(finalPrice), style: Theme.of(context).textTheme.headlineMedium),
                        Text(context.tr('end_debited'), style: TextStyle(color: eden.muted)),
                        const SizedBox(height: 4),
                        Text(
                          '${context.tr('trip_estimated')} : ${formatXaf(trip.estimate.price)}',
                          style: TextStyle(color: eden.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (overrun) ...[
                      InfoBanner(
                        color: AppColors.warning,
                        icon: Icons.warning_amber_rounded,
                        text: context.tr('end_overrun_alert', {'percent': '$alertPercent'}),
                      ),
                      TextButton(onPressed: () => _reportOverrun(trip), child: Text(context.tr('end_report'))),
                      const SizedBox(height: 8),
                    ],
                    if (wallet != null && wallet.isBlocked) ...[
                      InfoBanner(
                        color: AppColors.sos,
                        icon: Icons.lock_outline,
                        text: context.tr('end_negative_balance', {'amount': formatXaf(wallet.balance)}),
                      ),
                      const SizedBox(height: 16),
                    ],
                    EdenCard(
                      child: Column(
                        children: [
                          if (trip.driver != null) ...[
                            Row(
                              children: [
                                AvatarInitial(name: trip.driver!.name),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(trip.driver!.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text(trip.driver!.plate, style: TextStyle(color: eden.muted, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(context.tr('end_rate'), style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 1; i <= 5; i++)
                                IconButton(
                                  iconSize: 38,
                                  icon: Icon(
                                    i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: i <= _stars ? AppColors.warning : eden.border,
                                  ),
                                  onPressed: () => setState(() => _stars = i),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _comment,
                            maxLines: 3,
                            decoration: InputDecoration(hintText: context.tr('end_comment')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: (_stars == 0 || _sending) ? null : _submitRating,
                      child: Text(context.tr('end_send_rating')),
                    ),
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: Text(context.tr('end_skip')),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
