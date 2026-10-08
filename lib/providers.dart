import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/mock/mock_backend.dart';
import 'data/repositories.dart';
import 'domain/models/place.dart';
import 'domain/models/rules_config.dart';
import 'domain/models/session.dart';
import 'domain/models/trip.dart';
import 'domain/models/wallet.dart';
import 'domain/models/wallet_transaction.dart';

// ------------------------------------------------------------ Backend

/// Faux backend. Pour brancher la vraie API : créer les classes Api* et
/// faire pointer les 3 providers ci-dessous dessus (selon AppConfig.useMock).
final mockBackendProvider = Provider<MockBackend>((ref) {
  final backend = MockBackend();
  ref.onDispose(backend.dispose);
  return backend;
});

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => ref.watch(mockBackendProvider));
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

// ------------------------------------------------------------ Wallet

final walletProvider = StreamProvider<Wallet>(
  (ref) => ref.watch(walletRepositoryProvider).watchWallet(),
);

final transactionsProvider = StreamProvider<List<WalletTransaction>>(
  (ref) => ref.watch(walletRepositoryProvider).watchTransactions(),
);

// ------------------------------------------------------------ Courses

final tripProvider = StreamProvider.family<Trip, String>(
  (ref, tripId) => ref.watch(tripRepositoryProvider).watchTrip(tripId),
);

final historyProvider = StreamProvider<List<Trip>>(
  (ref) => ref.watch(tripRepositoryProvider).watchHistory(),
);

/// Brouillon de commande : départ + destination choisis sur l'accueil.
class BookingDraft {
  final Place? pickup;
  final Place? destination;

  const BookingDraft({this.pickup, this.destination});

  bool get isComplete => pickup != null && destination != null;
}

class BookingNotifier extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  void setPickup(Place p) =>
      state = BookingDraft(pickup: p, destination: state.destination);

  void setDestination(Place d) =>
      state = BookingDraft(pickup: state.pickup, destination: d);

  void clearDestination() => state = BookingDraft(pickup: state.pickup);
}

final bookingProvider = NotifierProvider<BookingNotifier, BookingDraft>(BookingNotifier.new);
