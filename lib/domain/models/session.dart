/// Session du passager connecté (module Auth + Users, CdC §4.1).
class Session {
  final String userId;

  /// Numéro au format national camerounais (9 chiffres), sans +237.
  final String phone;

  /// Prénom FACULTATIF (DÉCISION du 08/10/2026) : sert à l'accueil
  /// « Bonjour [prénom] ». Vide ou null → « Bonjour ».
  final String? firstName;

  /// CdC §2.2 : « consentement explicite sur l'usage des données ».
  final DateTime? consentAt;

  /// CdC §2.2 : « contact d'urgence pré-enregistré » (bouton SOS).
  final String? emergencyContactPhone;

  const Session({
    required this.userId,
    required this.phone,
    this.firstName,
    this.consentAt,
    this.emergencyContactPhone,
  });

  bool get consentGiven => consentAt != null;

  Session copyWith({
    String? firstName,
    bool clearFirstName = false,
    DateTime? consentAt,
    String? emergencyContactPhone,
  }) {
    return Session(
      userId: userId,
      phone: phone,
      firstName: clearFirstName ? null : (firstName ?? this.firstName),
      consentAt: consentAt ?? this.consentAt,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
    );
  }
}
