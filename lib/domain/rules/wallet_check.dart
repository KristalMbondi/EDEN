import '../models/rules_config.dart';
import '../models/wallet.dart';

enum WalletDecision {
  /// Solde suffisant : la course peut être commandée.
  sufficient,

  /// Solde insuffisant mais crédit d'urgence possible (le passager doit
  /// l'accepter explicitement).
  emergencyCredit,

  /// Commande refusée : recharger le wallet.
  refused,
}

enum RefusalReason {
  accountBlocked,
  insufficientNotEligible,
  creditAlreadyUsedThisWeek,
  creditCapExceeded,
  platformCreditSuspended,
}

class WalletCheckResult {
  final WalletDecision decision;

  /// Montant manquant (FCFA) = estimation − solde, 0 si suffisant.
  final int shortfall;
  final RefusalReason? reason;

  const WalletCheckResult(this.decision, {this.shortfall = 0, this.reason});
}

/// Vérification du wallet à la confirmation (CdC §2.2) :
/// « solde suffisant, crédit d'urgence, ou refus ».
///
/// HYPOTHÈSES (CdC muet, voir SPEC §6) :
/// - « suffisant » = solde ≥ prix ESTIMÉ (pas de marge pour un éventuel
///   dépassement du prix final) ;
/// - le crédit d'urgence couvre le MANQUE (estimation − solde), et ce manque
///   doit rester ≤ au plafond.
///
/// En production, cette décision est prise par le backend ; l'application
/// utilise la même logique uniquement pour l'affichage.
WalletCheckResult checkWalletForTrip({
  required Wallet wallet,
  required int estimatedPrice,
  required EmergencyCreditConfig config,
}) {
  if (wallet.isBlocked) {
    return const WalletCheckResult(
      WalletDecision.refused,
      reason: RefusalReason.accountBlocked,
    );
  }
  if (wallet.balance >= estimatedPrice) {
    return const WalletCheckResult(WalletDecision.sufficient);
  }

  final shortfall = estimatedPrice - wallet.balance;

  switch (wallet.emergencyCreditStatus) {
    case EmergencyCreditStatus.notEligible:
      return WalletCheckResult(
        WalletDecision.refused,
        shortfall: shortfall,
        reason: RefusalReason.insufficientNotEligible,
      );
    case EmergencyCreditStatus.usedThisWeek:
      return WalletCheckResult(
        WalletDecision.refused,
        shortfall: shortfall,
        reason: RefusalReason.creditAlreadyUsedThisWeek,
      );
    case EmergencyCreditStatus.eligible:
      break;
  }

  if (wallet.platformCreditSuspended) {
    return WalletCheckResult(
      WalletDecision.refused,
      shortfall: shortfall,
      reason: RefusalReason.platformCreditSuspended,
    );
  }
  if (shortfall > config.maxAmount) {
    return WalletCheckResult(
      WalletDecision.refused,
      shortfall: shortfall,
      reason: RefusalReason.creditCapExceeded,
    );
  }
  return WalletCheckResult(WalletDecision.emergencyCredit, shortfall: shortfall);
}
