import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../domain/models/favorite_place.dart';
import '../../domain/models/place.dart';
import '../../providers.dart';
import '../common/eden_map.dart';
import '../common/ui_helpers.dart';

/// Choix d'un lieu sur la carte (destination d'une course ou emplacement
/// d'un lieu favori). Renvoie le `Place` choisi avec `context.pop(place)`.
///
/// La recherche d'adresse par texte (géocodage) n'est pas spécifiée par le
/// CdC (point ouvert) : on choisit en touchant la carte, dans les favoris ou
/// dans les lieux de démonstration.
class PlacePickerScreen extends ConsumerStatefulWidget {
  const PlacePickerScreen({super.key, this.forFavorite = false});

  final bool forFavorite;

  @override
  ConsumerState<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends ConsumerState<PlacePickerScreen> {
  Place? _selected;

  void _select(Place p) => setState(() => _selected = p);

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(currentLocationProvider);
    final favorites = ref.watch(favoritesProvider).valueOrNull ?? const <FavoritePlace>[];
    final eden = context.eden;

    return Scaffold(
      body: locationAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(context.tr('home_locating')),
            ],
          ),
        ),
        error: (e, _) => ErrorView(error: e),
        data: (location) {
          final selected = _selected;
          return Stack(
            children: [
              Positioned.fill(
                child: EdenMap(
                  center: selected?.position ?? location.position,
                  zoom: 14,
                  onTap: (LatLng p) => _select(Place(label: context.tr('home_point_on_map'), position: p)),
                  markers: [
                    pinMarker(location.position, color: AppColors.primary, icon: Icons.my_location),
                    if (selected != null) pinMarker(selected.position, color: AppColors.accent),
                  ],
                ),
              ),
              // Barre du haut : retour + consigne.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _RoundButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EdenCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.touch_app_outlined, size: 20, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  context.tr(widget.forFavorite ? 'picker_hint_favorite' : 'home_tap_map_hint'),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Panneau du bas : favoris, lieux de démo, confirmation.
              Align(
                alignment: Alignment.bottomCenter,
                child: BottomPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr(widget.forFavorite ? 'picker_title_favorite' : 'picker_title_destination'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (location.isFallback) ...[
                        const SizedBox(height: 4),
                        Text(context.tr('home_default_position'),
                            style: TextStyle(color: eden.muted, fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            if (!widget.forFavorite)
                              for (final f in favorites) ...[
                                ChoiceChip(
                                  avatar: Icon(favoriteIcon(f.kind), size: 16, color: AppColors.accent),
                                  label: Text(favoriteLabel(context, f)),
                                  selected: selected?.position == f.place.position,
                                  onSelected: (_) => _select(
                                      Place(label: favoriteLabel(context, f), position: f.place.position)),
                                ),
                                const SizedBox(width: 8),
                              ],
                            for (final p in AppConfig.demoPlaces) ...[
                              ChoiceChip(
                                label: Text(p.label),
                                selected: selected?.position == p.position,
                                onSelected: (_) => _select(p),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
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
                                selected?.label ?? context.tr('picker_nothing_selected'),
                                style: TextStyle(
                                  fontWeight: selected == null ? FontWeight.w400 : FontWeight.w600,
                                  color: selected == null ? eden.muted : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: selected == null ? null : () => context.pop(selected),
                        child: Text(context.tr(widget.forFavorite ? 'picker_confirm_favorite' : 'picker_confirm')),
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.eden.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 46, height: 46, child: Icon(icon, size: 18)),
      ),
    );
  }
}

/// Bouton rond flottant réutilisé par les écrans carte.
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _RoundButton(icon: icon, onTap: onTap);
}
