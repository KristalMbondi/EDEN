import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../domain/models/trip.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Recherche chauffeur avec timeout de 60 s (CdC §2.2).
/// Le compte à rebours est indicatif : c'est le backend qui décide du
/// passage à `noDriverFound`.
class SearchingScreen extends ConsumerStatefulWidget {
  const SearchingScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends ConsumerState<SearchingScreen> {
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
      appBar: AppBar(
        title: Text(context.tr('searching_title')),
        automaticallyImplyLeading: false,
      ),
      body: tripAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (trip) {
          if (trip.status == TripStatus.noDriverFound) {
            return _NoDriver(onRetry: () => context.pushReplacement('/estimate'));
          }
          if (trip.status == TripStatus.cancelledByPassenger) {
            return const LoadingView();
          }
          final elapsed = DateTime.now().difference(trip.createdAt);
          final remaining = (timeout - elapsed).inSeconds.clamp(0, timeout.inSeconds);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: SizedBox(width: 72, height: 72, child: CircularProgressIndicator(strokeWidth: 6))),
                const SizedBox(height: 32),
                Text(
                  context.tr('searching_message'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('searching_remaining', {'seconds': '$remaining'}),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                OutlinedButton(
                  onPressed: _cancelling ? null : _cancel,
                  child: Text(context.tr('searching_cancel_free')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoDriver extends StatelessWidget {
  const _NoDriver({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.car_crash_outlined, size: 64),
          const SizedBox(height: 16),
          Text(context.tr('searching_no_driver'), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          FilledButton(onPressed: onRetry, child: Text(context.tr('common_retry'))),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => context.go('/home'), child: Text(context.tr('common_back_home'))),
        ],
      ),
    );
  }
}
