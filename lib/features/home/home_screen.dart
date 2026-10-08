import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/favorite_place.dart';
import '../../domain/models/place.dart';
import '../../domain/models/trip.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Accueil personnalisé (décision du 08/10/2026, inspiré de la maquette 1) :
/// « Bonjour [prénom] », recherche de destination, lieux favoris,
/// tuiles Commander / Wallet / Courses, course en cours et réservations.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Ouvre le choix de destination puis l'estimation.
  static Future<void> startBooking(BuildContext context, WidgetRef ref, {Place? destination}) async {
    final picked = destination ?? await context.push<Place>('/pick-place');
    if (picked == null || !context.mounted) return;
    final location = await ref.read(currentLocationProvider.future);
    if (!context.mounted) return;
    ref.read(bookingProvider.notifier).set(
          pickup: Place(label: context.tr('home_my_position'), position: location.position),
          destination: picked,
        );
    context.push('/estimate');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final wallet = ref.watch(walletProvider).valueOrNull;
    final favorites = ref.watch(favoritesProvider).valueOrNull ?? const <FavoritePlace>[];
    final history = ref.watch(historyProvider).valueOrNull ?? const <Trip>[];
    final activeTrip = history.where((t) => t.status.isActive).firstOrNull;
    final upcoming = history.where((t) => t.status == TripStatus.scheduled).toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    final eden = context.eden;
    final firstName = session?.firstName;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---------------------------------------------- En-tête dégradé
          SoftGradient(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AvatarInitial(name: firstName),
                        const Spacer(),
                        if (wallet != null)
                          ActionChip(
                            avatar: const Icon(Icons.account_balance_wallet_outlined,
                                size: 18, color: AppColors.primary),
                            label: Text(formatXaf(wallet.balance),
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            onPressed: () => context.go('/wallet'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      (firstName == null || firstName.isEmpty)
                          ? context.tr('home_hello')
                          : context.tr('home_hello_name', {'name': firstName}),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(context.tr('home_subtitle'),
                        style: TextStyle(color: eden.muted, fontSize: 15)),
                    const SizedBox(height: 20),
                    // Barre « Où allez-vous ? »
                    EdenCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      onTap: activeTrip == null ? () => startBooking(context, ref) : null,
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(context.tr('home_where_to'),
                                style: TextStyle(color: eden.muted, fontSize: 15)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(context.tr('home_go'),
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ------------------------------------- Course en cours
                if (activeTrip != null) ...[
                  EdenCard(
                    color: eden.primarySoft,
                    onTap: () => context.push(
                      activeTrip.status == TripStatus.searching
                          ? '/searching/${activeTrip.id}'
                          : '/trip/${activeTrip.id}',
                    ),
                    child: Row(
                      children: [
                        const IconBubble(icon: Icons.local_taxi_rounded, background: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('home_active_trip'),
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(tripStatusLabel(context, activeTrip.status),
                                  style: TextStyle(color: eden.muted, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ------------------------------------- Réservations
                for (final r in upcoming) ...[
                  _ReservationCard(trip: r),
                  const SizedBox(height: 12),
                ],
                if (upcoming.isNotEmpty) const SizedBox(height: 4),

                // ------------------------------------- Lieux favoris
                SectionTitle(
                  context.tr('home_favorites'),
                  trailing: TextButton(
                    onPressed: () => context.push('/favorites'),
                    child: Text(context.tr('common_manage')),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in favorites) ...[
                        ActionChip(
                          avatar: Icon(favoriteIcon(f.kind), size: 18, color: AppColors.accent),
                          label: Text(favoriteLabel(context, f)),
                          onPressed: activeTrip == null
                              ? () => startBooking(context, ref,
                                  destination: Place(label: favoriteLabel(context, f), position: f.place.position))
                              : null,
                        ),
                        const SizedBox(width: 8),
                      ],
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                        label: Text(context.tr('home_add_favorite')),
                        onPressed: () => context.push('/favorites'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ------------------------------------- Tuiles
                SectionTitle(context.tr('home_shortcuts')),
                Row(
                  children: [
                    Expanded(
                      child: _Tile(
                        icon: Icons.local_taxi_rounded,
                        title: context.tr('home_tile_ride'),
                        subtitle: context.tr('home_tile_ride_sub'),
                        onTap: activeTrip == null ? () => startBooking(context, ref) : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Tile(
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: AppColors.accent,
                        iconBackground: eden.accentSoft,
                        title: context.tr('home_tile_wallet'),
                        subtitle: wallet == null ? '…' : formatXaf(wallet.balance),
                        onTap: () => context.go('/wallet'),
                        action: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () => context.push('/wallet/recharge'),
                          child: Text(context.tr('wallet_recharge')),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Tile(
                  icon: Icons.receipt_long_rounded,
                  title: context.tr('home_tile_history'),
                  subtitle: context.tr('home_tile_history_sub'),
                  onTap: () => context.go('/history'),
                  horizontal: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppColors.primary,
    this.iconBackground,
    this.action,
    this.horizontal = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color? iconBackground;
  final Widget? action;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    final bubble = IconBubble(icon: icon, color: iconColor, background: iconBackground);
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: eden.muted, fontSize: 13)),
        if (action != null) action!,
      ],
    );
    return EdenCard(
      onTap: onTap,
      child: horizontal
          ? Row(
              children: [
                bubble,
                const SizedBox(width: 12),
                Expanded(child: texts),
                const Icon(Icons.chevron_right_rounded),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bubble, const SizedBox(height: 12), texts],
            ),
    );
  }
}

/// Carte d'une réservation à venir, avec l'alerte de solde le cas échéant.
class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    return EdenCard(
      onTap: () => context.push('/history/${trip.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBubble(icon: Icons.event_rounded, color: AppColors.accent, background: eden.accentSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('home_reservation', {'when': formatDayTime(context, trip.scheduledAt!)}),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${categoryLabel(context, trip.category)} · ${trip.destination.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: eden.muted, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          if (trip.lowBalanceWarning) ...[
            const SizedBox(height: 12),
            InfoBanner(
              color: AppColors.warning,
              icon: Icons.warning_amber_rounded,
              text: context.tr('home_reservation_low_balance'),
            ),
          ],
        ],
      ),
    );
  }
}
