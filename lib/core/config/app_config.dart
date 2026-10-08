import 'package:latlong2/latlong.dart';

import '../../domain/models/place.dart';
import '../../domain/models/rules_config.dart';
import '../../domain/models/vehicle_category.dart';

/// Configuration de l'application.
///
/// ⚠️ TOUTES LES VALEURS CHIFFRÉES CI-DESSOUS SONT FICTIVES.
/// Le cahier des charges (§9) ne fixe volontairement aucun tarif, aucun
/// plafond ni aucun montant : ils doivent venir d'une étude terrain et
/// d'une décision de l'entreprise, puis être servis par le backend.
class AppConfig {
  AppConfig._();

  /// `true` : l'application tourne sur le faux backend en mémoire
  /// (lib/data/mock). Passer à `false` quand l'API NestJS existera.
  static const bool useMock = true;

  /// Code OTP accepté par le faux backend.
  static const String demoOtpCode = '123456';

  /// Montant minimum de recharge (FICTIF).
  static const int minRechargeAmount = 100;

  /// Centre de Yaoundé (zone pilote, CdC §6). Position par défaut si le GPS
  /// est indisponible.
  static final LatLng yaoundeCenter = LatLng(3.8480, 11.5021);

  /// Règles de démonstration — VALEURS FICTIVES, NON VALIDÉES.
  static const AppRulesConfig demoRules = AppRulesConfig(
    // Tarifs séparés par gamme (décision du 08/10/2026) — montants FICTIFS.
    pricingByCategory: {
      VehicleCategory.eco: PricingConfig(
        pickupFee: 500,
        perKm: 250,
        minimumFare: 1000,
        overrunAlertPercent: 30, // ce seuil-là vient du CdC §2.2
      ),
      VehicleCategory.confort: PricingConfig(
        pickupFee: 800,
        perKm: 350,
        minimumFare: 1500,
        overrunAlertPercent: 30,
      ),
    },
    cancellation: CancellationConfig(
      freeWindow: Duration(minutes: 3), // CdC §3.2
      feePerMinute: 50, // FICTIF
      capMinutes: 10, // CdC §3.2
    ),
    emergencyCredit: EmergencyCreditConfig(maxAmount: 2000), // FICTIF
    // Fenêtre 1 h – 24 h, alerte 30 min avant, recherche 15 min avant
    // (décision du 08/10/2026).
    reservation: ReservationConfig(),
    searchTimeout: Duration(seconds: 60), // CdC §2.2
  );

  /// Raccourcis de destination pour la démo.
  /// Coordonnées APPROXIMATIVES, à vérifier sur une carte avant tout usage
  /// réel. En production : recherche d'adresse via un service de géocodage
  /// (non spécifié par le CdC — point ouvert).
  static final List<Place> demoPlaces = [
    Place(label: 'Poste centrale', position: LatLng(3.8610, 11.5170)),
    Place(label: 'Bastos', position: LatLng(3.8930, 11.5080)),
    Place(label: 'Marché Mokolo', position: LatLng(3.8750, 11.4990)),
    Place(label: 'Université de Yaoundé I', position: LatLng(3.8600, 11.4990)),
    Place(label: 'Mvan', position: LatLng(3.8310, 11.5160)),
    Place(label: 'Aéroport de Nsimalen', position: LatLng(3.7226, 11.5533)),
  ];
}
