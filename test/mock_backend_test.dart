import 'package:eden_mobility_passager/data/mock/mock_backend.dart';
import 'package:eden_mobility_passager/domain/errors.dart';
import 'package:eden_mobility_passager/domain/models/favorite_place.dart';
import 'package:eden_mobility_passager/domain/models/place.dart';
import 'package:eden_mobility_passager/domain/models/trip.dart';
import 'package:eden_mobility_passager/domain/models/vehicle_category.dart';
import 'package:eden_mobility_passager/domain/models/wallet_transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  late MockBackend backend;
  final pickup = Place(label: 'A', position: LatLng(3.8610, 11.5170));
  final destination = Place(label: 'B', position: LatLng(3.8930, 11.5080));

  setUp(() => backend = MockBackend());
  tearDown(() => backend.dispose());

  test('OTP : mauvais code refusé, bon code accepté', () async {
    await expectLater(backend.verifyOtp('699000000', '000000'), throwsA(isA<AppException>()));
    final s = await backend.verifyOtp('699000000', '123456');
    expect(s.consentGiven, isFalse); // consentement explicite requis ensuite
  });

  test('prénom facultatif : vide → null, rempli → conservé', () async {
    await backend.verifyOtp('699000000', '123456');
    var s = await backend.completeProfile(firstName: '   ');
    expect(s.consentGiven, isTrue);
    expect(s.firstName, isNull);
    s = await backend.updateFirstName('Kristal');
    expect(s.firstName, 'Kristal');
  });

  test('une estimation par gamme, Confort plus cher qu\'Éco (tarifs de démo)', () async {
    final est = await backend.estimate(pickup, destination);
    expect(est.map((e) => e.category), VehicleCategory.values);
    final eco = est.firstWhere((e) => e.category == VehicleCategory.eco);
    final confort = est.firstWhere((e) => e.category == VehicleCategory.confort);
    expect(confort.price, greaterThan(eco.price));
  });

  test('nouveau wallet : solde 0 → commande refusée', () async {
    final est = (await backend.estimate(pickup, destination)).first;
    await expectLater(
      backend.requestTrip(pickup: pickup, destination: destination, estimate: est, useEmergencyCredit: false),
      throwsA(isA<AppException>()),
    );
  });

  test('après recharge : commande acceptée, puis annulation gratuite en recherche', () async {
    await backend.recharge(operator: MobileMoneyOperator.mtnMomo, payerPhone: '677000000', amount: 10000);
    final est = (await backend.estimate(pickup, destination)).first;
    final trip = await backend.requestTrip(
      pickup: pickup,
      destination: destination,
      estimate: est,
      useEmergencyCredit: false,
    );
    expect(trip.status, TripStatus.searching);

    final cancelled = await backend.cancelTrip(trip.id);
    expect(cancelled.status, TripStatus.cancelledByPassenger);
    expect(cancelled.cancellationFee, 0);
  });

  test('réservation : refusée trop tôt, acceptée à +2 h, annulation gratuite', () async {
    await backend.recharge(operator: MobileMoneyOperator.orangeMoney, payerPhone: '699000000', amount: 10000);
    final est = (await backend.estimate(pickup, destination)).first;

    await expectLater(
      backend.requestTrip(
        pickup: pickup,
        destination: destination,
        estimate: est,
        useEmergencyCredit: false,
        scheduledAt: DateTime.now().add(const Duration(minutes: 30)),
      ),
      throwsA(isA<AppException>()),
    );

    final trip = await backend.requestTrip(
      pickup: pickup,
      destination: destination,
      estimate: est,
      useEmergencyCredit: false,
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
    );
    expect(trip.status, TripStatus.scheduled);
    expect(trip.isReservation, isTrue);

    final cancelled = await backend.cancelTrip(trip.id);
    expect(cancelled.status, TripStatus.cancelledByPassenger);
    expect(cancelled.cancellationFee, 0);
  });

  test('réservation refusée si le solde ne couvre pas l\'estimation', () async {
    backend.sim.eligibleForEmergencyCredit = true; // ne doit rien changer
    final est = (await backend.estimate(pickup, destination)).first;
    await expectLater(
      backend.requestTrip(
        pickup: pickup,
        destination: destination,
        estimate: est,
        useEmergencyCredit: true,
        scheduledAt: DateTime.now().add(const Duration(hours: 3)),
      ),
      throwsA(isA<AppException>()),
    );
  });

  test('favoris : Maison unique (remplacée), lieu libre sans nom refusé', () async {
    await backend.saveFavorite(kind: FavoriteKind.home, place: pickup);
    await backend.saveFavorite(kind: FavoriteKind.home, place: destination);
    await backend.saveFavorite(kind: FavoriteKind.custom, place: pickup, customName: 'École');
    await expectLater(
      backend.saveFavorite(kind: FavoriteKind.custom, place: pickup, customName: '  '),
      throwsA(isA<AppException>()),
    );
    final favs = await backend.watchFavorites().first;
    expect(favs.where((f) => f.kind == FavoriteKind.home).length, 1);
    expect(favs.firstWhere((f) => f.kind == FavoriteKind.home).place.label, 'B');
    expect(favs.length, 2);
  });
}
