// Tests des règles métier du cahier des charges (pur Dart, sans UI).
// Lancer : flutter test

import 'package:eden_mobility_passager/domain/models/rules_config.dart';
import 'package:eden_mobility_passager/domain/models/trip.dart';
import 'package:eden_mobility_passager/domain/models/wallet.dart';
import 'package:eden_mobility_passager/domain/rules/cancellation.dart';
import 'package:eden_mobility_passager/domain/rules/pricing.dart';
import 'package:eden_mobility_passager/domain/rules/reservation.dart';
import 'package:eden_mobility_passager/domain/rules/wallet_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Valeurs de TEST (indépendantes des valeurs de démo).
  const pricing = PricingConfig(pickupFee: 400, perKm: 300, minimumFare: 1200);

  group('Pricing — CdC §3.1', () {
    test('prix = prise en charge + tarif_km × distance', () {
      // 400 + 300 × 3,5 = 1450
      expect(computeFare(distanceKm: 3.5, config: pricing), 1450);
    });

    test('le prix minimum s\'applique sur une course courte', () {
      // 400 + 300 × 2 = 1000 < 1200
      expect(computeFare(distanceKm: 2, config: pricing), 1200);
    });

    test('arrondi à l\'unité FCFA la plus proche', () {
      // 400 + 300 × 3,345 = 1403,5 → 1404 (au-dessus du minimum de 1200)
      expect(computeFare(distanceKm: 3.345, config: pricing), 1404);
    });

    test('distance négative refusée', () {
      expect(() => computeFare(distanceKm: -1, config: pricing), throwsArgumentError);
    });
  });

  group('Alerte dépassement > 30 % — CdC §2.2', () {
    test('exactement +30 % : pas d\'alerte', () {
      expect(isFareOverrun(estimatedPrice: 1000, finalPrice: 1300, alertPercent: 30), isFalse);
    });

    test('+30 % et 1 FCFA : alerte', () {
      expect(isFareOverrun(estimatedPrice: 1000, finalPrice: 1301, alertPercent: 30), isTrue);
    });

    test('prix final inférieur : pas d\'alerte', () {
      expect(isFareOverrun(estimatedPrice: 1000, finalPrice: 900, alertPercent: 30), isFalse);
    });
  });

  group('Frais d\'annulation — CdC §3.2', () {
    const cfg = CancellationConfig(feePerMinute: 50);
    final accepted = DateTime(2026, 10, 8, 10, 0, 0);

    CancellationQuote quote(TripStatus s, Duration after) => computeCancellationQuote(
          status: s,
          acceptedAt: s == TripStatus.searching ? null : accepted,
          now: accepted.add(after),
          config: cfg,
        );

    test('gratuit avant acceptation', () {
      expect(quote(TripStatus.searching, Duration.zero).outcome, CancellationOutcome.free);
    });

    test('gratuit à 2 min 59 s après acceptation', () {
      expect(quote(TripStatus.driverAssigned, const Duration(minutes: 2, seconds: 59)).outcome,
          CancellationOutcome.free);
    });

    test('payant à 3 min pile (« moins de 3 minutes » = gratuit)', () {
      final q = quote(TripStatus.driverAssigned, const Duration(minutes: 3));
      expect(q.outcome, CancellationOutcome.withFee);
      expect(q.fee, 150); // 3 × 50
    });

    test('proportionnel : 5 min 30 s → 275 FCFA', () {
      expect(quote(TripStatus.driverArrived, const Duration(minutes: 5, seconds: 30)).fee, 275);
    });

    test('plafonné à 10 minutes', () {
      expect(quote(TripStatus.driverAssigned, const Duration(minutes: 25)).fee, 500);
    });

    test('impossible une fois la course démarrée', () {
      expect(quote(TripStatus.inProgress, const Duration(minutes: 1)).outcome,
          CancellationOutcome.notAllowed);
    });
  });

  group('Vérification wallet — CdC §2.2 / §2.6', () {
    const credit = EmergencyCreditConfig(maxAmount: 2000);

    WalletCheckResult check(Wallet w, int price) =>
        checkWalletForTrip(wallet: w, estimatedPrice: price, config: credit);

    test('solde suffisant', () {
      expect(check(const Wallet(balance: 3000), 2500).decision, WalletDecision.sufficient);
    });

    test('solde exactement égal : suffisant', () {
      expect(check(const Wallet(balance: 2500), 2500).decision, WalletDecision.sufficient);
    });

    test('nouvel inscrit (solde 0, non éligible) : refus', () {
      final r = check(const Wallet(balance: 0), 1500);
      expect(r.decision, WalletDecision.refused);
      expect(r.reason, RefusalReason.insufficientNotEligible);
      expect(r.shortfall, 1500);
    });

    test('éligible et manque ≤ plafond : crédit d\'urgence proposé', () {
      final r = check(
        const Wallet(balance: 500, emergencyCreditStatus: EmergencyCreditStatus.eligible),
        2000,
      );
      expect(r.decision, WalletDecision.emergencyCredit);
      expect(r.shortfall, 1500);
    });

    test('éligible mais manque > plafond : refus', () {
      final r = check(
        const Wallet(balance: 0, emergencyCreditStatus: EmergencyCreditStatus.eligible),
        2500,
      );
      expect(r.reason, RefusalReason.creditCapExceeded);
    });

    test('crédit déjà utilisé dans les 7 jours : refus', () {
      final r = check(
        const Wallet(balance: 0, emergencyCreditStatus: EmergencyCreditStatus.usedThisWeek),
        1000,
      );
      expect(r.reason, RefusalReason.creditAlreadyUsedThisWeek);
    });

    test('solde négatif : compte bloqué, même pour une petite course', () {
      final r = check(
        const Wallet(balance: -200, emergencyCreditStatus: EmergencyCreditStatus.eligible),
        100,
      );
      expect(r.reason, RefusalReason.accountBlocked);
    });

    test('protection trésorerie globale : refus', () {
      final r = check(
        const Wallet(
          balance: 0,
          emergencyCreditStatus: EmergencyCreditStatus.eligible,
          platformCreditSuspended: true,
        ),
        1000,
      );
      expect(r.reason, RefusalReason.platformCreditSuspended);
    });
  });

  group('Machine à états de la course', () {
    test('transitions valides', () {
      expect(canTransition(TripStatus.searching, TripStatus.driverAssigned), isTrue);
      expect(canTransition(TripStatus.inProgress, TripStatus.completed), isTrue);
    });

    test('transitions interdites', () {
      expect(canTransition(TripStatus.completed, TripStatus.searching), isFalse);
      expect(canTransition(TripStatus.searching, TripStatus.completed), isFalse);
      expect(canTransition(TripStatus.inProgress, TripStatus.cancelledByPassenger), isFalse);
    });

    test('chaque statut a une entrée dans la table', () {
      for (final s in TripStatus.values) {
        expect(allowedTripTransitions.containsKey(s), isTrue, reason: s.name);
      }
    });
  });

  group('Réservation — décision du 08/10/2026 (1 h – 24 h)', () {
    const cfg = ReservationConfig();
    final now = DateTime(2026, 10, 8, 13, 47);

    test('59 min avant : trop tôt', () {
      expect(
        validateReservationTime(scheduledAt: now.add(const Duration(minutes: 59)), now: now, config: cfg),
        ReservationError.tooSoon,
      );
    });

    test('1 h pile et 24 h pile : acceptées (bornes incluses)', () {
      expect(validateReservationTime(scheduledAt: now.add(const Duration(hours: 1)), now: now, config: cfg), isNull);
      expect(validateReservationTime(scheduledAt: now.add(const Duration(hours: 24)), now: now, config: cfg), isNull);
    });

    test('24 h et 1 min : trop tard', () {
      expect(
        validateReservationTime(
            scheduledAt: now.add(const Duration(hours: 24, minutes: 1)), now: now, config: cfg),
        ReservationError.tooLate,
      );
    });

    test('créneaux : quarts d\'heure, tous valides', () {
      final slots = reservationSlots(now: now, config: cfg);
      // 13:47 + 1 h = 14:47 → premier quart d'heure valide : 15:00
      expect(slots.first, DateTime(2026, 10, 8, 15, 0));
      // dernier ≤ 13:47 le lendemain → 13:45
      expect(slots.last, DateTime(2026, 10, 9, 13, 45));
      for (final s in slots) {
        expect(s.minute % 15, 0);
        expect(validateReservationTime(scheduledAt: s, now: now, config: cfg), isNull);
      }
    });

    test('annulation d\'une réservation : gratuite', () {
      final q = computeCancellationQuote(
        status: TripStatus.scheduled,
        acceptedAt: null,
        now: now,
        config: const CancellationConfig(feePerMinute: 50),
      );
      expect(q.outcome, CancellationOutcome.free);
    });

    test('wallet : solde suffisant exigé, pas de crédit d\'urgence', () {
      expect(
        evaluateReservationWallet(wallet: const Wallet(balance: 2000), estimatedPrice: 2000).decision,
        WalletDecision.sufficient,
      );
      final r = evaluateReservationWallet(
        wallet: const Wallet(balance: 500, emergencyCreditStatus: EmergencyCreditStatus.eligible),
        estimatedPrice: 2000,
      );
      expect(r.decision, WalletDecision.refused);
      expect(r.reason, RefusalReason.insufficientForReservation);
      expect(r.shortfall, 1500);
    });

    test('transitions d\'une réservation', () {
      expect(canTransition(TripStatus.scheduled, TripStatus.searching), isTrue);
      expect(canTransition(TripStatus.scheduled, TripStatus.cancelledInsufficientBalance), isTrue);
      expect(canTransition(TripStatus.scheduled, TripStatus.completed), isFalse);
      expect(TripStatus.scheduled.isActive, isFalse);
    });
  });
}
