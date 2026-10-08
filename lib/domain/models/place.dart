import 'package:latlong2/latlong.dart';

/// Un lieu : libellé affiché + coordonnées GPS.
class Place {
  final String label;
  final LatLng position;

  const Place({required this.label, required this.position});

  @override
  String toString() => 'Place($label, ${position.latitude}, ${position.longitude})';
}
