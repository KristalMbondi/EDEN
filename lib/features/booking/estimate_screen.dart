import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/fare_estimate.dart';
import '../../domain/rules/wallet_check.dart';
import '../../providers.dart';
import '../common/eden_map.dart';
import '../common/ui_helpers.dart';

/// Écran d'estimation (CdC §4.3) : prix / durée affichés AVANT confirmation,
/// puis vérification du wallet : solde suffisant, crédit d'urgence ou refus.
class EstimateScreen extends ConsumerStatefulWidget {
  const EstimateScreen({super.key});

  @override
  ConsumerState<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends ConsumerState<EstimateScreen> {
  FareEstimate? _estimate;
  WalletCheckResult? _check;
  Object? _error;
  bool _ordering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final draft = ref.read(bookingProvider);
    if (!draft.isComplete) {
      setState(() => _error = StateError('booking incomplete'));
      return;
    }
    setState(() {
      _error = null;
      _estimate = null;
      _check = null;
    });
    try {
      final estimate = await ref.read(tripRepositoryProvider).estimate(draft.pickup!, draft.destination!);
      final check = await ref.read(walletRepositoryProvider).checkWallet(estimate.price);
      if (!mounted) return;
      setState(() {
        _estimate = estimate;
        _check = check;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _order({required bool useEmergencyCredit}) async {
    final draft = ref.read(bookingProvider);
    setState(() => _ordering = true);
    try {
      final trip = await ref.read(tripRepositoryProvider).requestTrip(
            pickup: draft.pickup!,
            destination: draft.destination!,
            estimate: _estimate!,
            useEmergencyCredit: useEmergencyCredit,
          );
      if (mounted) context.pushReplacement('/searching/${trip.id}');
    } catch (e) {
      if (mounted) {
        showError(context, e);
        _load(); // la situation du wallet a pu changer
      }
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingProvider);
    final estimate = _estimate;
    final check = _check;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('estimate_title'))),
      body: _error != null
          ? ErrorView(error: _error!)
          : (estimate == null || check == null || !draft.isComplete)
              ? const LoadingView()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SizedBox(
                      height: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: EdenMap(
                          center: draft.pickup!.position,
                          fitPoints: [draft.pickup!.position, draft.destination!.position],
                          route: [draft.pickup!.position, draft.destination!.position],
                          markers: [
                            pinMarker(draft.pickup!.position, color: AppColors.primary, icon: Icons.my_location),
                            pinMarker(draft.destination!.position, color: AppColors.accent),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('${draft.pickup!.label}  →  ${draft.destination!.label}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(context.tr('estimate_price'), style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 4),
                            Text(formatXaf(estimate.price), style: Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 8),
                            Text('${formatKm(estimate.distanceKm)} · ~${estimate.durationMin} min'),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('estimate_final_price_note'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._walletSection(context, check),
                  ],
                ),
    );
  }

  List<Widget> _walletSection(BuildContext context, WalletCheckResult check) {
    switch (check.decision) {
      case WalletDecision.sufficient:
        return [
          InfoBanner(text: context.tr('estimate_wallet_ok'), icon: Icons.account_balance_wallet_outlined),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _ordering ? null : () => _order(useEmergencyCredit: false),
            child: Text(context.tr('estimate_confirm')),
          ),
        ];
      case WalletDecision.emergencyCredit:
        return [
          InfoBanner(
            color: AppColors.warning,
            icon: Icons.warning_amber_rounded,
            text: context.tr('estimate_credit_offer', {'amount': formatXaf(check.shortfall)}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _ordering ? null : () => _order(useEmergencyCredit: true),
            child: Text(context.tr('estimate_use_credit')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.push('/wallet/recharge').then((_) => _load()),
            child: Text(context.tr('wallet_recharge')),
          ),
        ];
      case WalletDecision.refused:
        var message = refusalLabel(context, check.reason!);
        if (check.shortfall > 0) {
          message += '\n${context.tr('estimate_missing', {'amount': formatXaf(check.shortfall)})}';
        }
        return [
          InfoBanner(color: AppColors.sos, icon: Icons.block, text: message),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/wallet/recharge').then((_) => _load()),
            child: Text(context.tr('wallet_recharge')),
          ),
        ];
    }
  }
}
