import 'dart:math' as math;

import '../models/rules_config.dart';
import '../models/trip.dart';

enum CancellationOutcome { free, withFee, notAllowed }

class CancellationQuote {
  final CancellationOutcome outcome;

  /// Frais en FCFA (0 si gratuit ou interdit).
  final int fee;

  const CancellationQuote(this.outcome, this.fee);

  static const free = CancellationQuote(CancellationOutcome.free, 0);
  static const notAllowed = CancellationQuote(CancellationOutcome.notAllowed, 0);
}

/// Frais d'annulation côté passager (CdC §3.2).
///
/// - Gratuit avant acceptation du chauffeur.
/// - Gratuit moins de 3 minutes après acceptation.
/// - Ensuite : frais proportionnels, plafonnés à 10 minutes.
///
/// INTERPRÉTATIONS (à valider, voir SPEC §6) :
/// 1. « proportionnels » = proportionnels au temps écoulé depuis
///    l'acceptation, au tarif `feePerMinute`.
/// 2. Le CdC dit « Après 3 minutes OU chauffeur déjà en route » : or le
///    chauffeur est en route dès l'acceptation, ce qui contredit la gratuité
///    < 3 min. On applique uniquement le critère des 3 minutes.
/// 3. Une fois le passager à bord (`inProgress`), l'annulation n'est plus
///    possible (le CdC ne traite pas ce cas) : on termine la course.
CancellationQuote computeCancellationQuote({
  required TripStatus status,
  required DateTime? acceptedAt,
  required DateTime now,
  required CancellationConfig config,
}) {
  switch (status) {
    // Réservation en attente et recherche : avant toute acceptation chauffeur,
    // donc gratuit (CdC §3.2).
    case TripStatus.scheduled:
    case TripStatus.searching:
      return CancellationQuote.free;
    case TripStatus.driverAssigned:
    case TripStatus.driverArrived:
      if (acceptedAt == null) return CancellationQuote.free;
      final elapsed = now.difference(acceptedAt);
      if (elapsed < config.freeWindow) return CancellationQuote.free;
      final minutes = elapsed.inSeconds / 60.0;
      final billable = math.min(minutes, config.capMinutes.toDouble());
      final fee = (billable * config.feePerMinute).round();
      return CancellationQuote(CancellationOutcome.withFee, fee);
    default:
      return CancellationQuote.notAllowed;
  }
}
