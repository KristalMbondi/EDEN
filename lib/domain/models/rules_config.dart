/// Paramètres métier configurables « sans redéploiement » (CdC §2.4).
///
/// En production, ces valeurs viennent du backend (table `Pricing_config`
/// + configuration admin). L'application passager ne fait que les LIRE :
/// le backend reste la seule source de vérité pour le prix et les frais.
library;

/// Tarification (CdC §3.1) :
/// Prix = frais_prise_en_charge + (tarif_km × distance)
/// Prix appliqué = max(Prix calculé, prix_minimum)
class PricingConfig {
  /// frais_prise_en_charge, en FCFA.
  final int pickupFee;

  /// tarif_km, en FCFA par km.
  final int perKm;

  /// prix_minimum, en FCFA.
  final int minimumFare;

  /// Seuil d'alerte si le prix final dépasse l'estimation (CdC §2.2 : 30 %).
  final int overrunAlertPercent;

  const PricingConfig({
    required this.pickupFee,
    required this.perKm,
    required this.minimumFare,
    this.overrunAlertPercent = 30,
  });
}

/// Frais d'annulation (CdC §3.2).
class CancellationConfig {
  /// Fenêtre gratuite après acceptation du chauffeur (CdC : 3 minutes).
  final Duration freeWindow;

  /// HYPOTHÈSE : le CdC parle de « frais proportionnels plafonnés à
  /// 10 minutes de trajet équivalent » sans définir de tarif à la minute.
  /// On le modélise par un montant par minute écoulée depuis l'acceptation.
  final int feePerMinute;

  /// Plafond, en minutes (CdC : 10).
  final int capMinutes;

  const CancellationConfig({
    this.freeWindow = const Duration(minutes: 3),
    required this.feePerMinute,
    this.capMinutes = 10,
  });
}

/// Crédit d'urgence (CdC §2.6).
class EmergencyCreditConfig {
  /// Plafond en montant (valeur non fixée par le CdC).
  final int maxAmount;

  /// Fenêtre glissante : 1 utilisation par période de 7 jours.
  final Duration usageWindow;

  const EmergencyCreditConfig({
    required this.maxAmount,
    this.usageWindow = const Duration(days: 7),
  });
}

/// Regroupe toute la configuration lue par l'application passager.
class AppRulesConfig {
  final PricingConfig pricing;
  final CancellationConfig cancellation;
  final EmergencyCreditConfig emergencyCredit;

  /// Recherche chauffeur : timeout de 60 secondes (CdC §2.2).
  final Duration searchTimeout;

  const AppRulesConfig({
    required this.pricing,
    required this.cancellation,
    required this.emergencyCredit,
    this.searchTimeout = const Duration(seconds: 60),
  });
}
