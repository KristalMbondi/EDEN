import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/trip.dart';
import '../../domain/rules/cancellation.dart';
import '../../providers.dart';
import '../booking/place_picker_screen.dart';
import '../common/eden_map.dart';
import '../common/ui_helpers.dart';

/// Écran de suivi (CdC §2.2 « Pendant la course », §4.3) :
/// position du chauffeur en temps réel, fiche chauffeur, numéros masqués,
/// bouton SOS visible en permanence.
class TripTrackingScreen extends ConsumerStatefulWidget {
  const TripTrackingScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends ConsumerState<TripTrackingScreen> {
  bool _busy = false;
  bool _navigated = false;

  // ------------------------------------------------------------ Actions

  Future<void> _sos(Trip trip) async {
    final contact = ref.read(sessionProvider)?.emergencyContactPhone;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.sos_rounded, color: AppColors.sos, size: 40),
        title: Text(context.tr('sos_title')),
        content: Text(context.tr('sos_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('common_cancel'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.sos),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('sos_send')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(tripRepositoryProvider).sendSos(trip.id);
      if (!mounted) return;
      showInfo(context, context.tr('sos_sent'));
      if (contact != null && contact.isNotEmpty) {
        await launchUrl(Uri(scheme: 'tel', path: '+237$contact'));
      } else {
        showInfo(context, context.tr('sos_no_contact'));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _callDriver() {
    // CdC §2.2 : numéros masqués. En production, le backend fournit un
    // numéro relais (fournisseur de masquage à choisir — point ouvert).
    showInfo(context, context.tr('trip_call_masked_demo'));
  }

  Future<void> _cancel(Trip trip) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(tripRepositoryProvider);
      final quote = await repo.quoteCancellation(trip.id);
      if (!mounted) return;
      if (quote.outcome == CancellationOutcome.notAllowed) {
        showInfo(context, context.tr('err_cancel_not_allowed'));
        return;
      }
      final message = quote.outcome == CancellationOutcome.free
          ? context.tr('cancel_free')
          : context.tr('cancel_with_fee', {'amount': formatXaf(quote.fee)});
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('cancel_title')),
          content: Text(message),
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
      await repo.cancelTrip(trip.id);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------------------------------------------------------- Navigation

  void _onTripUpdate(Trip trip) {
    if (_navigated) return;
    switch (trip.status) {
      case TripStatus.completed:
        _navigated = true;
        context.pushReplacement('/trip/${trip.id}/end');
      case TripStatus.cancelledByDriver:
        _navigated = true;
        _showDriverCancelled();
      default:
        break;
    }
  }

  Future<void> _showDriverCancelled() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(context.tr('driver_cancelled_title')),
        content: Text(context.tr('driver_cancelled_message')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('common_ok'))),
        ],
      ),
    );
    if (mounted) context.pushReplacement('/estimate');
  }

  // --------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Trip>>(tripProvider(widget.tripId), (_, next) {
      final trip = next.valueOrNull;
      if (trip != null) _onTripUpdate(trip);
    });

    final tripAsync = ref.watch(tripProvider(widget.tripId));
    return tripAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(error: e)),
      data: (trip) => _buildTrip(context, trip),
    );
  }

  Widget _buildTrip(BuildContext context, Trip trip) {
    final eden = context.eden;
    final driverPos = trip.driverPosition;
    final target = trip.status == TripStatus.inProgress ? trip.destination.position : trip.pickup.position;
    final route = <LatLng>[if (driverPos != null) driverPos, target];
    final canCancel = trip.status == TripStatus.driverAssigned || trip.status == TripStatus.driverArrived;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 280,
            child: EdenMap(
              center: trip.pickup.position,
              fitPoints: [trip.pickup.position, trip.destination.position, if (driverPos != null) driverPos],
              route: route,
              markers: [
                pinMarker(trip.pickup.position, color: AppColors.primary, icon: Icons.my_location),
                pinMarker(trip.destination.position, color: AppColors.accent),
                if (driverPos != null) pinMarker(driverPos, color: AppColors.primary, icon: Icons.local_taxi_rounded),
              ],
            ),
          ),
          // Haut : retour + statut + SOS (visible en permanence).
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  MapRoundButton(icon: Icons.close_rounded, onTap: () => context.go('/home')),
                  const Spacer(),
                  EdenCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text(tripStatusLabel(context, trip.status),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const Spacer(),
                  Material(
                    color: AppColors.sos,
                    shape: const StadiumBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => _sos(trip),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Text(context.tr('sos_button'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (trip.status == TripStatus.incident) ...[
                    InfoBanner(
                      text: context.tr('trip_incident'),
                      color: AppColors.warning,
                      icon: Icons.report_problem_outlined,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (trip.status == TripStatus.driverArrived) ...[
                    InfoBanner(
                      text: context.tr('trip_driver_arrived_hint'),
                      icon: Icons.emoji_people_rounded,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (trip.driver != null) _DriverCard(trip: trip, onCall: _callDriver),
                  const SizedBox(height: 12),
                  // Trajet
                  _RouteLine(from: trip.pickup.label, to: trip.destination.label),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(categoryIcon(trip.category), size: 18, color: eden.muted),
                      const SizedBox(width: 6),
                      Text(categoryLabel(context, trip.category), style: TextStyle(color: eden.muted)),
                      const Spacer(),
                      Text('${context.tr('trip_estimated')} : ',
                          style: TextStyle(color: eden.muted, fontSize: 13)),
                      Text(formatXaf(trip.estimate.price), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (canCancel) ...[
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _cancel(trip),
                      child: Text(context.tr('cancel_title')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Identification du chauffeur et du véhicule AVANT la montée à bord.
class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.trip, required this.onCall});

  final Trip trip;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final d = trip.driver!;
    final eden = context.eden;
    return EdenCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AvatarInitial(name: d.name, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: 2),
                    Text(d.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(d.vehicleModel, style: TextStyle(color: eden.muted, fontSize: 12.5)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: eden.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(d.plate,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.primary, fontSize: 12)),
                ),
              ],
            ),
          ),
          Material(
            color: eden.accentSoft,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: context.tr('trip_call_driver'),
              icon: const Icon(Icons.phone_rounded, color: AppColors.accent),
              onPressed: onCall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Départ → destination sous forme de deux lignes reliées.
class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    return Row(
      children: [
        Column(
          children: [
            const Icon(Icons.radio_button_checked, size: 16, color: AppColors.primary),
            Container(width: 2, height: 18, color: eden.border),
            const Icon(Icons.place_rounded, size: 18, color: AppColors.accent),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(from, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              Text(to, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
