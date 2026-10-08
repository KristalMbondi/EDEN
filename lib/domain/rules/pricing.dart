import 'dart:math' as math;

import '../models/rules_config.dart';

/// Formule de pricing du CdC §3.1 :
///   Prix = frais_prise_en_charge + (tarif_km × distance)
///   Prix appliqué = max(Prix calculé, prix_minimum)
///
/// Arrondi : le CdC ne précise pas de règle d'arrondi. On arrondit à l'unité
/// FCFA la plus proche (`round`). POINT OUVERT : un pas commercial (25 ou 50
/// FCFA) est à décider par l'entreprise.
int computeFare({required double distanceKm, required PricingConfig config}) {
  if (distanceKm.isNaN || distanceKm < 0) {
    throw ArgumentError.value(distanceKm, 'distanceKm', 'doit être un nombre >= 0');
  }
  final computed = (config.pickupFee + config.perKm * distanceKm).round();
  return math.max(computed, config.minimumFare);
}

/// CdC §2.2 « Alerte si dépassement de plus de 30 % par rapport à
/// l'estimation ». Calcul en entiers pour éviter les erreurs de virgule
/// flottante : final > estimé × (100 + seuil) / 100.
/// Exactement +30 % ne déclenche PAS l'alerte (« plus de 30 % »).
bool isFareOverrun({
  required int estimatedPrice,
  required int finalPrice,
  required int alertPercent,
}) {
  return finalPrice * 100 > estimatedPrice * (100 + alertPercent);
}
