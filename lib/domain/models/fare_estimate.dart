import 'vehicle_category.dart';

/// Estimation affichée AVANT confirmation (CdC §2.2 « Estimation prix/durée »),
/// pour une gamme de véhicule donnée.
class FareEstimate {
  final VehicleCategory category;
  final double distanceKm;
  final int durationMin;

  /// Prix estimé en FCFA (calculé par le backend en production).
  final int price;

  const FareEstimate({
    required this.category,
    required this.distanceKm,
    required this.durationMin,
    required this.price,
  });
}
