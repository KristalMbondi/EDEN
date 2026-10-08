/// Contrats entre l'application et le backend.
///
/// Les écrans ne connaissent QUE ces interfaces. Aujourd'hui elles sont
/// implémentées par `MockBackend` (lib/data/mock). Demain, il suffira
/// d'écrire `ApiAuthRepository`, `ApiWalletRepository`, `ApiTripRepository`
/// (REST + Socket.io vers NestJS) et de changer les providers : aucun écran
/// n'aura à être modifié. Voir docs/SPEC_APP_PASSAGER.md §5 (contrat API).
library;

import '../domain/models/fare_estimate.dart';
import '../domain/models/place.dart';
import '../domain/models/rules_config.dart';
import '../domain/models/session.dart';
import '../domain/models/trip.dart';
import '../domain/models/wallet.dart';
import '../domain/models/wallet_transaction.dart';
import '../domain/rules/cancellation.dart';
import '../domain/rules/wallet_check.dart';

/// Module Auth (CdC §2.2 Inscription : téléphone → OTP SMS → compte).
abstract class AuthRepository {
  Future<void> requestOtp(String phone);

  /// Lève `AppException('err_otp_invalid')` si le code est faux.
  Future<Session> verifyOtp(String phone, String code);

  Future<Session> giveConsent();

  Future<Session> updateEmergencyContact(String phone);

  Future<void> logout();
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

  Future<WalletCheckResult> checkWallet(int estimatedPrice);
}

/// Modules Trips + Pricing + Geo.
abstract class TripRepository {
  Future<AppRulesConfig> fetchConfig();

  Future<FareEstimate> estimate(Place pickup, Place destination);

  /// Lève `AppException` si le wallet refuse la commande.
  Future<Trip> requestTrip({
    required Place pickup,
    required Place destination,
    required FareEstimate estimate,
    required bool useEmergencyCredit,
  });

  /// Suivi temps réel d'une course (Socket.io en production).
  Stream<Trip> watchTrip(String tripId);

  /// Historique, du plus récent au plus ancien.
  Stream<List<Trip>> watchHistory();

  Future<CancellationQuote> quoteCancellation(String tripId);

  Future<Trip> cancelTrip(String tripId);

  Future<void> rateTrip(String tripId, int stars, String? comment);

  /// Bouton SOS (CdC §2.2) → crée un `Incident` côté backend.
  Future<void> sendSos(String tripId);

  /// Signalement après course (ex. dépassement > 30 %) → `Incident`/litige.
  Future<void> reportIssue(String tripId, String message);
}
