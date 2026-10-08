import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/fare_estimate.dart';
import '../../domain/models/rules_config.dart';
import '../../domain/models/vehicle_category.dart';
import '../../domain/rules/reservation.dart';
import '../../domain/rules/wallet_check.dart';
import '../../providers.dart';
import '../common/eden_map.dart';
import '../common/ui_helpers.dart';
import 'place_picker_screen.dart';

/// Choix de la course (inspiré de la maquette 1) : carte en haut, panneau
/// en bas avec les gammes Éco / Confort, « Maintenant » ou « Plus tard »
/// (réservation 1 h – 24 h), puis vérification du wallet.
class EstimateScreen extends ConsumerStatefulWidget {
  const EstimateScreen({super.key});

  @override
  ConsumerState<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends ConsumerState<EstimateScreen> {
  List<FareEstimate>? _estimates;
  VehicleCategory _category = VehicleCategory.eco;
  DateTime? _scheduledAt; // null = maintenant
  WalletCheckResult? _check;
  Object? _error;
  bool _ordering = false;

  FareEstimate? get _selected =>
      _estimates?.where((e) => e.category == _category).firstOrNull;

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
    setState(() => _error = null);
    try {
      final estimates = await ref.read(tripRepositoryProvider).estimate(draft.pickup!, draft.destination!);
      if (!mounted) return;
      setState(() => _estimates = estimates);
      await _refreshCheck();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// La vérification du wallet dépend de la gamme et du mode (maintenant /
  /// réservation) : on la refait à chaque changement.
  Future<void> _refreshCheck() async {
    final est = _selected;
    if (est == null) return;
    setState(() => _check = null);
    final repo = ref.read(walletRepositoryProvider);
    final check = _scheduledAt == null
        ? await repo.checkWallet(est.price)
        : await repo.checkWalletForReservation(est.price);
    if (mounted) setState(() => _check = check);
  }

  Future<void> _pickTime(ReservationConfig config) async {
    final slots = reservationSlots(now: DateTime.now(), config: config);
    final chosen = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SlotSheet(slots: slots, current: _scheduledAt),
    );
    if (chosen == null) return;
    setState(() => _scheduledAt = chosen);
    _refreshCheck();
  }

  Future<void> _order({required bool useEmergencyCredit}) async {
    final draft = ref.read(bookingProvider);
    final est = _selected;
    if (est == null) return;
    setState(() => _ordering = true);
    try {
      final trip = await ref.read(tripRepositoryProvider).requestTrip(
            pickup: draft.pickup!,
            destination: draft.destination!,
            estimate: est,
            useEmergencyCredit: useEmergencyCredit,
            scheduledAt: _scheduledAt,
          );
      if (!mounted) return;
      if (trip.isReservation) {
        showInfo(context, context.tr('estimate_reserved', {'when': formatDayTime(context, trip.scheduledAt!)}));
        context.go('/home');
      } else {
        context.pushReplacement('/searching/${trip.id}');
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
        _refreshCheck(); // la situation du wallet a pu changer
      }
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingProvider);
    final rules = ref.watch(rulesConfigProvider).valueOrNull;

    if (_error != null || !draft.isComplete) {
      return Scaffold(appBar: AppBar(), body: ErrorView(error: _error ?? StateError('')));
    }
    final pickup = draft.pickup!;
    final destination = draft.destination!;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 300,
            child: EdenMap(
              center: pickup.position,
              fitPoints: [pickup.position, destination.position],
              route: [pickup.position, destination.position],
              markers: [
                pinMarker(pickup.position, color: AppColors.primary, icon: Icons.my_location),
                pinMarker(destination.position, color: AppColors.accent),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: MapRoundButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => context.pop()),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomPanel(
              child: (_estimates == null || rules == null)
                  ? const Padding(padding: EdgeInsets.all(32), child: LoadingView())
                  : _panel(context, rules, pickup.label, destination.label),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, AppRulesConfig rules, String from, String to) {
    final eden = context.eden;
    final estimates = _estimates!;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.68),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('estimate_choose'),
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('$from  →  $to',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: eden.muted, fontSize: 13)),
            const SizedBox(height: 14),
            for (final e in estimates) ...[
              _CategoryCard(
                estimate: e,
                selected: e.category == _category,
                onTap: () {
                  setState(() => _category = e.category);
                  _refreshCheck();
                },
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            // Maintenant / Plus tard
            Row(
              children: [
                Expanded(
                  child: _WhenChip(
                    icon: Icons.bolt_rounded,
                    label: context.tr('estimate_now'),
                    selected: _scheduledAt == null,
                    onTap: () {
                      setState(() => _scheduledAt = null);
                      _refreshCheck();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WhenChip(
                    icon: Icons.schedule_rounded,
                    label: _scheduledAt == null
                        ? context.tr('estimate_later')
                        : formatDayTime(context, _scheduledAt!),
                    selected: _scheduledAt != null,
                    onTap: () => _pickTime(rules.reservation),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('estimate_final_price_note'),
              textAlign: TextAlign.center,
              style: TextStyle(color: eden.muted, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            ..._walletSection(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _walletSection(BuildContext context) {
    final check = _check;
    final est = _selected;
    if (check == null || est == null) {
      return const [Padding(padding: EdgeInsets.all(12), child: LoadingView())];
    }
    final catName = categoryLabel(context, est.category);
    final confirmLabel = _scheduledAt == null
        ? context.tr('estimate_confirm_cat', {'category': catName})
        : context.tr('estimate_reserve_cat',
            {'category': catName, 'when': formatDayTime(context, _scheduledAt!)});
    switch (check.decision) {
      case WalletDecision.sufficient:
        return [
          FilledButton(
            onPressed: _ordering ? null : () => _order(useEmergencyCredit: false),
            child: Text(confirmLabel),
          ),
        ];
      case WalletDecision.emergencyCredit:
        return [
          InfoBanner(
            color: AppColors.warning,
            icon: Icons.warning_amber_rounded,
            text: context.tr('estimate_credit_offer', {'amount': formatXaf(check.shortfall)}),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _ordering ? null : () => _order(useEmergencyCredit: true),
            child: Text(context.tr('estimate_use_credit')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.push('/wallet/recharge').then((_) => _refreshCheck()),
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
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/wallet/recharge').then((_) => _refreshCheck()),
            child: Text(context.tr('wallet_recharge')),
          ),
        ];
    }
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.estimate, required this.selected, required this.onTap});

  final FareEstimate estimate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    return EdenCard(
      selected: selected,
      color: selected ? eden.primarySoft : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          IconBubble(
            icon: categoryIcon(estimate.category),
            size: 48,
            background: selected ? eden.surface : eden.primarySoft,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryLabel(context, estimate.category),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(
                  '${formatKm(estimate.distanceKm)} · ~${estimate.durationMin} min',
                  style: TextStyle(color: eden.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Text(formatXaf(estimate.price),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }
}

class _WhenChip extends StatelessWidget {
  const _WhenChip({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    return EdenCard(
      selected: selected,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: selected ? AppColors.primary : eden.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? AppColors.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste des créneaux de réservation (tous les quarts d'heure, 1 h – 24 h).
class _SlotSheet extends StatelessWidget {
  const _SlotSheet({required this.slots, required this.current});

  final List<DateTime> slots;
  final DateTime? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Text(context.tr('estimate_pick_time'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(context.tr('estimate_pick_time_rule'),
                style: TextStyle(color: context.eden.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: slots.length,
                itemBuilder: (context, i) {
                  final s = slots[i];
                  final isCurrent = current == s;
                  return ListTile(
                    leading: Icon(Icons.schedule_rounded,
                        color: isCurrent ? AppColors.primary : context.eden.muted),
                    title: Text(formatDayTime(context, s),
                        style: TextStyle(fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400)),
                    trailing: isCurrent ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                    onTap: () => Navigator.of(context).pop(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
