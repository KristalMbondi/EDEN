import 'package:latlong2/latlong.dart';

import 'fare_estimate.dart';
import 'place.dart';

/// Cycle de vie d'une course (module Trips, CdC §4.1).
///
/// Les noms d'états ne sont pas fixés par le CdC : ils sont déduits des
/// parcours décrits en §2.2, §2.3, §3.2 et de la gestion des risques (§7).
enum TripStatus {
  /// Recherche chauffeur en cours (timeout 60 s).
  searching,

  /// Chauffeur a accepté, il est en route vers le point de prise en charge.
  driverAssigned,

  /// Chauffeur arrivé au point de prise en charge.
  driverArrived,

  /// Passager à bord, trajet vers la destination.
  inProgress,

  /// Course terminée, wallet débité au prix final réel.
  completed,

  cancelledByPassenger,

  /// Gratuit pour le passager (CdC §3.2).
  cancelledByDriver,

  /// Timeout de recherche atteint sans chauffeur.
  noDriverFound,

  /// Panne serveur / anomalie : wallet NON débité tant que non résolu (CdC §7).
  incident,
}

/// Transitions autorisées. Toute autre transition est un bug ou une fraude.
const Map<TripStatus, Set<TripStatus>> allowedTripTransitions = {
  TripStatus.searching: {
    TripStatus.driverAssigned,
    TripStatus.noDriverFound,
    TripStatus.cancelledByPassenger,
    TripStatus.incident,
  },
  TripStatus.driverAssigned: {
    TripStatus.driverArrived,
    TripStatus.cancelledByPassenger,
    TripStatus.cancelledByDriver,
    TripStatus.incident,
  },
  TripStatus.driverArrived: {
    TripStatus.inProgress,
    TripStatus.cancelledByPassenger,
    TripStatus.cancelledByDriver,
    TripStatus.incident,
  },
  TripStatus.inProgress: {
    TripStatus.completed,
    TripStatus.incident,
  },
  // États terminaux côté application passager (l'incident est résolu
  // par l'administration dans le back-office).
  TripStatus.completed: <TripStatus>{},
  TripStatus.cancelledByPassenger: <TripStatus>{},
  TripStatus.cancelledByDriver: <TripStatus>{},
  TripStatus.noDriverFound: <TripStatus>{},
  TripStatus.incident: <TripStatus>{},
};

bool canTransition(TripStatus from, TripStatus to) =>
    allowedTripTransitions[from]?.contains(to) ?? false;

extension TripStatusX on TripStatus {
  /// Course « vivante » : l'écran de suivi doit rester accessible.
  bool get isActive =>
      this == TripStatus.searching ||
      this == TripStatus.driverAssigned ||
      this == TripStatus.driverArrived ||
      this == TripStatus.inProgress;

  bool get isFinal => (allowedTripTransitions[this] ?? const <TripStatus>{}).isEmpty;
}

/// Informations chauffeur affichées au passager (CdC §4.3 « infos chauffeur »).
class DriverInfo {
  final String name;
  final double rating;
  final String vehicleModel;
  final String plate;

  const DriverInfo({
    required this.name,
    required this.rating,
    required this.vehicleModel,
    required this.plate,
  });
}

class Trip {
  final String id;
  final Place pickup;
  final Place destination;
  final TripStatus status;
  final FareEstimate estimate;
  final DateTime createdAt;

  /// Moment de l'acceptation chauffeur : sert au calcul des frais d'annulation.
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  final DriverInfo? driver;
  final LatLng? driverPosition;

  /// Prix final réel débité (FCFA).
  final int? finalPrice;

  /// Frais d'annulation débités (FCFA), le cas échéant.
  final int? cancellationFee;

  /// La course a été commandée en utilisant le crédit d'urgence.
  final bool paidWithEmergencyCredit;

  /// Note 1 à 5 (CdC §2.2) + commentaire optionnel (`Trip_ratings`).
  final int? rating;
  final String? ratingComment;

  const Trip({
    required this.id,
    required this.pickup,
    required this.destination,
    required this.status,
    required this.estimate,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.driver,
    this.driverPosition,
    this.finalPrice,
    this.cancellationFee,
    this.paidWithEmergencyCredit = false,
    this.rating,
    this.ratingComment,
  });

  Trip copyWith({
    TripStatus? status,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DriverInfo? driver,
    LatLng? driverPosition,
    int? finalPrice,
    int? cancellationFee,
    int? rating,
    String? ratingComment,
  }) {
    return Trip(
      id: id,
      pickup: pickup,
      destination: destination,
      status: status ?? this.status,
      estimate: estimate,
      createdAt: createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      driver: driver ?? this.driver,
      driverPosition: driverPosition ?? this.driverPosition,
      finalPrice: finalPrice ?? this.finalPrice,
      cancellationFee: cancellationFee ?? this.cancellationFee,
      paidWithEmergencyCredit: paidWithEmergencyCredit,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
    );
  }
}
