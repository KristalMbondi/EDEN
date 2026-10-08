import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../domain/models/trip.dart';
import '../../providers.dart';
import '../common/eden_map.dart';
import '../common/ui_helpers.dart';

/// Recherche chauffeur avec timeout de 60 s (CdC §2.2), inspirée de l'écran
/// « Looking for a driver… » de la maquette 2.
/// Le compte à rebours est indicatif : c'est le backend qui décide du
/// passage à `noDriverFound`.
class SearchingScreen extends ConsumerStatefulWidget {
  const SearchingScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends ConsumerState<SearchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  Timer? _ticker;
  bool _cancelling = false;
  bool _navigated = false; // évite une double navigation

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      // Avant acceptation : annulation toujours gratuite (CdC §3.2).
      await ref.read(tripRepositoryProvider).cancelTrip(widget.tripId);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Trip>>(tripProvider(widget.tripId), (_, next) {
      final trip = next.valueOrNull;
      if (trip == null || _navigated) return;
      if (trip.status == TripStatus.driverAssigned ||
          trip.status == TripStatus.driverArrived ||
          trip.status == TripStatus.inProgress) {
        _navigated = true;
        context.pushReplacement('/trip/${trip.id}');
      }
    });

    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final timeout = ref.watch(rulesConfigProvider).valueOrNull?.searchTimeout ?? const Duration(seconds: 60);

    return Scaffold(
      body: tripAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (trip) {
          final eden = context.eden;
          final noDriver = trip.status == TripStatus.noDriverFound;
          final elapsed = DateTime.now().difference(trip.createdAt);
          final remaining = (timeout - elapsed).inSeconds.clamp(0, timeout.inSeconds);
          return Stack(
            children: [
              Positioned.fill(
                child: EdenMap(
                  center: trip.pickup.position,
                  zoom: 15,
                  markers: [pinMarker(trip.pickup.position, color: AppColors.primary, icon: Icons.my_location)],
                ),
              ),
              // Cercles pulsants autour du point de départ.
              if (!noDriver)
                Positioned.fill(
                  bottom: 260,
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) {
                          final t = _pulse.value;
                          return Container(
                            width: 80 + 160 * t,
                            height: 80 + 160 * t,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.25 * (1 - t)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: BottomPanel(
                  child: noDriver
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(
                              child: IconBubble(
                                  icon: Icons.car_crash_outlined, size: 64, color: AppColors.warning),
                            ),
                            const SizedBox(height: 16),
                            Text(context.tr('searching_no_driver'), textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () => context.pushReplacement('/estimate'),
                              child: Text(context.tr('common_retry')),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => context.go('/home'),
                              child: Text(context.tr('common_back_home')),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(child: IconBubble(icon: Icons.search_rounded, size: 64)),
                            const SizedBox(height: 16),
                            Text(
                              context.tr('searching_message'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('searching_remaining', {'seconds': '$remaining'}),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: eden.muted),
                            ),
                            const SizedBox(height: 14),
                            EdenCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.place_rounded, color: AppColors.accent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${categoryLabel(context, trip.category)} · ${trip.destination.label}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: _cancelling ? null : _cancel,
                              child: Text(context.tr('searching_cancel_free')),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
