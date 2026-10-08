/// Ligne du ledger (CdC §4.4 `Wallet_transactions`).
///
/// Le ledger est IMMUABLE : on n'édite ni ne supprime jamais une ligne.
/// Une correction = une nouvelle opération (ex. `refund`).
library;

enum TransactionType { recharge, tripPayment, cancellationFee, refund }

enum MobileMoneyOperator { orangeMoney, mtnMomo }

class WalletTransaction {
  final String id;
  final TransactionType type;

  /// Montant signé en FCFA : positif = crédit, négatif = débit.
  final int amount;

  /// Solde après l'opération (facilite l'affichage et l'audit).
  final int balanceAfter;

  final DateTime createdAt;
  final String? tripId;
  final MobileMoneyOperator? operator;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.tripId,
    this.operator,
  });
}
