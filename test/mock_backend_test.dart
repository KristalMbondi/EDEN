import 'package:eden_mobility_passager/data/mock/mock_backend.dart';
import 'package:eden_mobility_passager/domain/errors.dart';
import 'package:eden_mobility_passager/domain/models/place.dart';
import 'package:eden_mobility_passager/domain/models/trip.dart';
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

  test('nouveau wallet : solde 0 → commande refusée', () async {
    final est = await backend.estimate(pickup, destination);
    await expectLater(
      backend.requestTrip(pickup: pickup, destination: destination, estimate: est, useEmergencyCredit: false),
      throwsA(isA<AppException>()),
    );
  });

  test('après recharge : commande acceptée, puis annulation gratuite en recherche', () async {
    await backend.recharge(operator: MobileMoneyOperator.mtnMomo, payerPhone: '677000000', amount: 10000);
    final est = await backend.estimate(pickup, destination);
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
}
