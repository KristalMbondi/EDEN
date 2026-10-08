/// Session du passager connecté (module Auth + Users, CdC §4.1).
class Session {
  final String userId;

  /// Numéro au format national camerounais (9 chiffres), sans +237.
  final String phone;

  /// CdC §2.2 : « consentement explicite sur l'usage des données ».
  final DateTime? consentAt;

  /// CdC §2.2 : « contact d'urgence pré-enregistré » (bouton SOS).
  final String? emergencyContactPhone;

  const Session({
    required this.userId,
    required this.phone,
    this.consentAt,
    this.emergencyContactPhone,
  });

  bool get consentGiven => consentAt != null;

  Session copyWith({DateTime? consentAt, String? emergencyContactPhone}) {
    return Session(
      userId: userId,
      phone: phone,
      consentAt: consentAt ?? this.consentAt,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
    );
  }
}
