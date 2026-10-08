/// Contrats entre l'application et le backend.
///
/// Les écrans ne connaissent QUE ces interfaces. Aujourd'hui elles sont
/// implémentées par `MockBackend` (lib/data/mock). Demain, il suffira
/// d'écrire les versions `Api…` (REST + Socket.io vers NestJS) et de changer
/// les providers : aucun écran n'aura à être modifié.
/// Voir docs/SPEC_APP_PASSAGER.md §5 (contrat API proposé).
library;

import '../domain/models/fare_estimate.dart';
import '../domain/models/favorite_place.dart';
import '../domain/models/place.dart';
import '../domain/models/rules_config.dart';
import '../domain/models/session.dart';
import '../domain/models/trip.dart';
import '../domain/models/wallet.dart';
import '../domain/models/wallet_transaction.dart';
import '../domain/rules/cancellation.dart';
import '../domain/rules/wallet_check.dart';

/// Module Auth + Users (CdC §2.2 Inscription : téléphone → OTP SMS → compte).
abstract class AuthRepository {
  Future<void> requestOtp(String phone);

  /// Lève `AppException('err_otp_invalid')` si le code est faux.
  Future<Session> verifyOtp(String phone, String code);

  /// Consentement explicite + prénom facultatif.
  Future<Session> completeProfile({required String? firstName});

  Future<Session> updateFirstName(String? firstName);

  Future<Session> updateEmergencyContact(String phone);

  Future<void> logout();
}

/// Lieux favoris (décision du 08/10/2026).
abstract class FavoritesRepository {
  Stream<List<FavoritePlace>> watchFavorites();

  /// Maison et Bureau sont uniques : les enregistrer remplace l'existant.
  Future<FavoritePlace> saveFavorite({
    required FavoriteKind kind,
    required Place place,
    String? customName,
  });

  Future<void> deleteFavorite(String id);
}

/// Module Wallet + Payments.
abstract class WalletRepository {
  /// Émet la valeur courante puis chaque mise à jour.
  Stream<Wallet> watchWallet();

  /// Ledger, du plus récent au plus ancien.
  Stream<List<WalletTransaction>> watchTransactions();

  /// Recharge Orange Money / MTN MoMo. En production, l'opération est
  /// asynchrone (validation PIN sur le téléphone puis webhook opérateur).
  Future<WalletTransaction> recharge({
    required MobileMoneyOperator operator,
    required String payerPhone,
    required int amount,
  });

  /// Course immédiate : solde suffisant, crédit d'urgence ou refus.
  Future<WalletCheckResult> checkWallet(int estimatedPrice);

  /// Réservation : solde suffisant ou refus.
  Future<WalletCheckResult> checkWalletForReservation(int estimatedPrice);
}

/// Modules Trips + Pricing + Geo.
abstract class TripRepository {
  Future<AppRulesConfig> fetchConfig();

  /// Une estimation par gamme de véhicule (Éco, Confort).
  Future<List<FareEstimate>> estimate(Place pickup, Place destination);

  /// `scheduledAt` null = course immédiate ; sinon réservation.
  /// Lève `AppException` si le wallet refuse ou si l'heure est invalide.
  Future<Trip> requestTrip({
    required Place pickup,
    required Place destination,
    required FareEstimate estimate,
    required bool useEmergencyCredit,
    DateTime? scheduledAt,
  });

  /// Suivi temps réel d'une course (Socket.io en production).
  Stream<Trip> watchTrip(String tripId);

  /// Historique et réservations, du plus récent au plus ancien.
  Stream<List<Trip>> watchHistory();

  Future<CancellationQuote> quoteCancellation(String tripId);

  Future<Trip> cancelTrip(String tripId);

  Future<void> rateTrip(String tripId, int stars, String? comment);

  /// Bouton SOS (CdC §2.2) → crée un `Incident` côté backend.
  Future<void> sendSos(String tripId);

  /// Signalement après course (ex. dépassement > 30 %) → `Incident`/litige.
  Future<void> reportIssue(String tripId, String message);
}
