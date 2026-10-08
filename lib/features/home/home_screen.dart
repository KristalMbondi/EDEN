import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/place.dart';
import '../../domain/models/trip.dart';
import '../../providers.dart';
import '../common/eden_map.dart';
import '../common/ui_helpers.dart';

/// Écran d'accueil (CdC §4.3) : carte, champ destination, bouton Commander.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _locating = true;
  bool _usedDefaultPosition = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  /// Récupère la position GPS ; à défaut, centre de Yaoundé.
  Future<void> _locate() async {
    LatLng position = AppConfig.yaoundeCenter;
    var fallback = true;
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          position = LatLng(p.latitude, p.longitude);
          fallback = false;
        }
      }
    } catch (_) {
      // GPS indisponible / délai dépassé : on garde la position par défaut.
    }
    if (!mounted) return;
    ref.read(bookingProvider.notifier).setPickup(
          Place(label: context.tr('home_my_position'), position: position),
        );
    setState(() {
      _locating = false;
      _usedDefaultPosition = fallback;
    });
  }

  void _pickOnMap(LatLng point) {
    ref.read(bookingProvider.notifier).setDestination(
          Place(label: context.tr('home_point_on_map'), position: point),
        );
  }

  Future<void> _openDestinationSheet() async {
    final place = await showModalBottomSheet<Place>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.touch_app_outlined),
              title: Text(context.tr('home_tap_map_hint')),
            ),
            const Divider(),
            for (final p in AppConfig.demoPlaces)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(p.label),
                onTap: () => Navigator.of(context).pop(p),
              ),
          ],
        ),
      ),
    );
    if (place != null) ref.read(bookingProvider.notifier).setDestination(place);
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider);
    final wallet = ref.watch(walletProvider).valueOrNull;
    final history = ref.watch(historyProvider).valueOrNull ?? const <Trip>[];
    final activeTrip = history.where((t) => t.status.isActive).firstOrNull;

    if (_locating || booking.pickup == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(context.tr('home_locating')),
            ],
          ),
        ),
      );
    }

    final pickup = booking.pickup!;
    final destination = booking.destination;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: EdenMap(
              center: pickup.position,
              zoom: 14,
              onTap: _pickOnMap,
              markers: [
                pinMarker(pickup.position, color: AppColors.primary, icon: Icons.my_location),
                if (destination != null) pinMarker(destination.position, color: AppColors.accent),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (activeTrip != null)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.directions_car),
                        title: Text(context.tr('home_active_trip')),
                        subtitle: Text(tripStatusLabel(context, activeTrip.status)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          activeTrip.status == TripStatus.searching
                              ? '/searching/${activeTrip.id}'
                              : '/trip/${activeTrip.id}',
                        ),
                      ),
                    ),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.my_location, color: AppColors.primary),
                          title: Text(pickup.label),
                          subtitle: _usedDefaultPosition ? Text(context.tr('home_default_position')) : null,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.place, color: AppColors.accent),
                          title: Text(destination?.label ?? context.tr('home_where_to')),
                          trailing: destination == null
                              ? const Icon(Icons.search)
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: context.tr('common_clear'),
                                  onPressed: () => ref.read(bookingProvider.notifier).clearDestination(),
                                ),
                          onTap: _openDestinationSheet,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wallet != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                      label: Text(formatXaf(wallet.balance)),
                      onPressed: () => context.go('/wallet'),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: (destination == null || activeTrip != null)
                      ? null
                      : () => context.push('/estimate'),
                  icon: const Icon(Icons.local_taxi),
                  label: Text(context.tr('home_order')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
