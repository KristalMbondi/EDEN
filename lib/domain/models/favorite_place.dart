import 'place.dart';

/// Lieux favoris (DÉCISION du 08/10/2026, hors CdC v1.0) :
/// Maison et Bureau (un seul de chaque) + lieux libres nommés par le passager.
enum FavoriteKind { home, work, custom }

class FavoritePlace {
  final String id;
  final FavoriteKind kind;

  /// Nom choisi par le passager ; uniquement pour `custom`.
  final String? customName;
  final Place place;

  const FavoritePlace({
    required this.id,
    required this.kind,
    required this.place,
    this.customName,
  });
}
