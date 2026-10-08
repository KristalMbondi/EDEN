import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Carte OpenStreetMap réutilisable.
///
/// ⚠️ Les tuiles tile.openstreetmap.org conviennent au DÉVELOPPEMENT.
/// Leur politique d'usage interdit un usage intensif en production :
/// prévoir un fournisseur de tuiles (payant ou auto-hébergé) avant le pilote.
class EdenMap extends StatelessWidget {
  const EdenMap({
    super.key,
    required this.center,
    this.zoom = 14,
    this.markers = const [],
    this.route = const [],
    this.fitPoints,
    this.onTap,
  });

  final LatLng center;
  final double zoom;
  final List<Marker> markers;

  /// Ligne affichée (ex. chauffeur → point de prise en charge).
  final List<LatLng> route;

  /// Si fourni (≥ 2 points), la carte s'ajuste pour tous les afficher.
  final List<LatLng>? fitPoints;

  final void Function(LatLng point)? onTap;

  @override
  Widget build(BuildContext context) {
    final fit = fitPoints;
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        initialCameraFit: (fit != null && fit.length >= 2)
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(fit),
                padding: const EdgeInsets.all(64),
                maxZoom: 16,
              )
            : null,
        onTap: onTap == null ? null : (_, point) => onTap!(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'cm.tacoeden.passager',
        ),
        if (route.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route,
                strokeWidth: 4,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}

/// Épingle colorée pour un lieu (départ, destination, chauffeur).
Marker pinMarker(LatLng point, {required Color color, IconData icon = Icons.location_on}) {
  return Marker(
    point: point,
    width: 44,
    height: 44,
    alignment: Alignment.topCenter,
    child: Icon(icon, color: color, size: 40),
  );
}
