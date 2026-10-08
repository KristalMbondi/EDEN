import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'data/mock/mock_backend.dart';
import 'data/repositories.dart';
import 'domain/models/favorite_place.dart';
import 'domain/models/place.dart';
import 'domain/models/rules_config.dart';
import 'domain/models/session.dart';
import 'domain/models/trip.dart';
import 'domain/models/wallet.dart';
import 'domain/models/wallet_transaction.dart';

// ------------------------------------------------------- Stockage local

/// Remplacé dans main.dart par l'instance chargée au démarrage.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider non initialisé'),
);

/// Écrans d'introduction déjà vus (mémorisé sur le téléphone).
class OnboardingNotifier extends Notifier<bool> {
  static const _key = 'onboarding_seen';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> markSeen() async {
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
    state = true;
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

// ------------------------------------------------------------ Backend

/// Faux backend. Pour brancher la vraie API : créer les classes Api* et
/// faire pointer les providers ci-dessous dessus (selon AppConfig.useMock).
final mockBackendProvider = Provider<MockBackend>((ref) {
  final backend = MockBackend();
  ref.onDispose(backend.dispose);
  return backend;
});

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => ref.watch(mockBackendProvider));
final favoritesRepositoryProvider =
    Provider<FavoritesRepository>((ref) => ref.watch(mockBackendProvider));
final walletRepositoryProvider =
    Provider<WalletRepository>((ref) => ref.watch(mockBackendProvider));
final tripRepositoryProvider =
    Provider<TripRepository>((ref) => ref.watch(mockBackendProvider));

final rulesConfigProvider = FutureProvider<AppRulesConfig>(
  (ref) => ref.watch(tripRepositoryProvider).fetchConfig(),
);

// ------------------------------------------------------------ Session

class SessionNotifier extends Notifier<Session?> {
  @override
  Session? build() => null;

  void setSession(Session? session) => state = session;
}

final sessionProvider = NotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

// ------------------------------------------------------------ Langue

/// `null` = langue du téléphone ; sinon fr / en choisi dans le profil.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  void setLocale(Locale? locale) => state = locale;
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

// ------------------------------------------------------------ Position

class CurrentLocation {
  final LatLng position;

  /// true si le GPS était indisponible et qu'on utilise le centre de Yaoundé.
  final bool isFallback;

  const CurrentLocation(this.position, {required this.isFallback});
}

/// Position GPS du passager ; à défaut, centre de Yaoundé.
final currentLocationProvider = FutureProvider<CurrentLocation>((ref) async {
  try {
    if (await Geolocator.isLocationServiceEnabled()) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        return CurrentLocation(LatLng(p.latitude, p.longitude), isFallback: false);
      }
    }
  } catch (_) {
    // GPS indisponible / délai dépassé : position par défaut ci-dessous.
  }
  return CurrentLocation(AppConfig.yaoundeCenter, isFallback: true);
});

// ------------------------------------------------------------ Données

final walletProvider = StreamProvider<Wallet>(
  (ref) => ref.watch(walletRepositoryProvider).watchWallet(),
);

final transactionsProvider = StreamProvider<List<WalletTransaction>>(
  (ref) => ref.watch(walletRepositoryProvider).watchTransactions(),
);

final favoritesProvider = StreamProvider<List<FavoritePlace>>(
  (ref) => ref.watch(favoritesRepositoryProvider).watchFavorites(),
);

final tripProvider = StreamProvider.family<Trip, String>(
  (ref, tripId) => ref.watch(tripRepositoryProvider).watchTrip(tripId),
);

final historyProvider = StreamProvider<List<Trip>>(
  (ref) => ref.watch(tripRepositoryProvider).watchHistory(),
);

// ------------------------------------------------------------ Commande

/// Brouillon de commande : départ + destination.
class BookingDraft {
  final Place? pickup;
  final Place? destination;

  const BookingDraft({this.pickup, this.destination});

  bool get isComplete => pickup != null && destination != null;
}

class BookingNotifier extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  void set({required Place pickup, required Place destination}) =>
      state = BookingDraft(pickup: pickup, destination: destination);

  void clear() => state = const BookingDraft();
}

final bookingProvider = NotifierProvider<BookingNotifier, BookingDraft>(BookingNotifier.new);
