/// Erreur métier affichable : `code` est une clé de traduction (voir
/// lib/core/l10n/strings.dart), jamais un texte en dur.
class AppException implements Exception {
  final String code;
  const AppException(this.code);

  @override
  String toString() => 'AppException($code)';
}
