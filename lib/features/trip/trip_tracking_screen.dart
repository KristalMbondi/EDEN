import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/trip.dart';
import '../../domain/rules/cancellation.dart';
import '../../providers.dart';
import '../common/eden_map.dart';
import '../common/ui_helpers.dart';

/// Écran de suivi (CdC §2.2 « Pendant la course », §4.3) :
/// position du chauffeur en temps réel, infos chauffeur, numéros masqués,
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
        icon: const Icon(Icons.sos, color: AppColors.sos, size: 40),
        title: Text(context.tr('sos_title')),
        content: Text(context.tr('sos_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('common_cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sos, minimumSize: const Size(0, 44)),
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
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('cancel_confirm'))),
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
    final driverPos = trip.driverPosition;
    final target = trip.status == TripStatus.inProgress ? trip.destination.position : trip.pickup.position;
    final route = <LatLng>[if (driverPos != null) driverPos, target];
    final canCancel = trip.status == TripStatus.driverAssigned || trip.status == TripStatus.driverArrived;

    return Scaffold(
      appBar: AppBar(
        title: Text(tripStatusLabel(context, trip.status)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/home')),
      ),
      // SOS visible en permanence pendant la course.
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sos',
        backgroundColor: AppColors.sos,
        foregroundColor: Colors.white,
        onPressed: () => _sos(trip),
        icon: const Icon(Icons.sos),
        label: Text(context.tr('sos_button')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: Column(
        children: [
          Expanded(
            child: EdenMap(
              center: trip.pickup.position,
              fitPoints: [trip.pickup.position, trip.destination.position, if (driverPos != null) driverPos],
              route: route,
              markers: [
                pinMarker(trip.pickup.position, color: AppColors.primary, icon: Icons.my_location),
                pinMarker(trip.destination.position, color: AppColors.accent),
                if (driverPos != null)
                  pinMarker(driverPos, color: Colors.black87, icon: Icons.local_taxi),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                    InfoBanner(text: context.tr('trip_driver_arrived_hint'), icon: Icons.emoji_people),
                    const SizedBox(height: 12),
                  ],
                  if (trip.driver != null) _DriverCard(trip: trip, onCall: _callDriver),
                  const SizedBox(height: 12),
                  Text(
                    '${context.tr('trip_estimated')} : ${formatXaf(trip.estimate.price)}',
                    textAlign: TextAlign.center,
                  ),
                  if (canCancel) ...[
                    const SizedBox(height: 12),
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
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(d.name.isNotEmpty ? d.name[0] : '?')),
        title: Text('${d.name}  ★ ${d.rating.toStringAsFixed(1)}'),
        subtitle: Text('${d.vehicleModel}\n${context.tr('trip_plate')} : ${d.plate}'),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.phone),
          tooltip: context.tr('trip_call_driver'),
          onPressed: onCall,
        ),
      ),
    );
  }
}
