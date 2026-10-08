/// Wallet prépayé du passager (CdC §1.1, §2.2, §2.6).
///
/// Règle : tous les montants sont des ENTIERS en FCFA (XAF).
/// Ne jamais utiliser de `double` pour de l'argent (erreurs d'arrondi).
library;

/// Statut vis-à-vis du crédit d'urgence (affiché au passager, CdC §2.2).
enum EmergencyCreditStatus {
  /// Statut par défaut à l'inscription (CdC §2.2).
  notEligible,

  /// Score de confiance suffisant (calculé par le backend, jamais par l'app).
  eligible,

  /// Déjà utilisé dans la période glissante de 7 jours.
  usedThisWeek,
}

class Wallet {
  /// Solde en FCFA. Peut être négatif après un crédit d'urgence.
  final int balance;

  final EmergencyCreditStatus emergencyCreditStatus;

  /// Blocage manuel par l'administration (litige, fraude…).
  final bool blockedByAdmin;

  /// Protection de trésorerie globale (CdC §2.6) : au-delà d'un seuil,
  /// l'octroi de nouveaux crédits est suspendu pour TOUS les passagers.
  final bool platformCreditSuspended;

  const Wallet({
    required this.balance,
    this.emergencyCreditStatus = EmergencyCreditStatus.notEligible,
    this.blockedByAdmin = false,
    this.platformCreditSuspended = false,
  });

  /// CdC §2.6 : « Blocage du compte tant que le solde reste négatif ».
  bool get isBlocked => blockedByAdmin || balance < 0;

  Wallet copyWith({
    int? balance,
    EmergencyCreditStatus? emergencyCreditStatus,
    bool? blockedByAdmin,
    bool? platformCreditSuspended,
  }) {
    return Wallet(
      balance: balance ?? this.balance,
      emergencyCreditStatus: emergencyCreditStatus ?? this.emergencyCreditStatus,
      blockedByAdmin: blockedByAdmin ?? this.blockedByAdmin,
      platformCreditSuspended: platformCreditSuspended ?? this.platformCreditSuspended,
    );
  }
}
