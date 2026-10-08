import '../models/rules_config.dart';

/// Réservation à l'avance (DÉCISION du 08/10/2026, hors CdC v1.0).
enum ReservationError {
  /// Moins de 1 h avant le départ.
  tooSoon,

  /// Plus de 24 h avant le départ.
  tooLate,
}

/// Vérifie que l'heure demandée est dans la fenêtre autorisée
/// (bornes incluses). Retourne null si l'heure est valide.
ReservationError? validateReservationTime({
  required DateTime scheduledAt,
  required DateTime now,
  required ReservationConfig config,
}) {
  final lead = scheduledAt.difference(now);
  if (lead < config.minLead) return ReservationError.tooSoon;
  if (lead > config.maxLead) return ReservationError.tooLate;
  return null;
}

/// Créneaux proposés au passager : tous les quarts d'heure, du premier
/// quart d'heure valide (≥ now + 1 h) jusqu'à now + 24 h.
/// Proposer uniquement des créneaux valides évite les erreurs de saisie.
List<DateTime> reservationSlots({
  required DateTime now,
  required ReservationConfig config,
  Duration step = const Duration(minutes: 15),
}) {
  final earliest = now.add(config.minLead);
  final latest = now.add(config.maxLead);
  // Arrondi au quart d'heure supérieur (secondes et millisecondes à zéro).
  final base = DateTime(earliest.year, earliest.month, earliest.day, earliest.hour);
  var slot = base;
  while (slot.isBefore(earliest)) {
    slot = slot.add(step);
  }
  final slots = <DateTime>[];
  while (!slot.isAfter(latest)) {
    slots.add(slot);
    slot = slot.add(step);
  }
  return slots;
}
