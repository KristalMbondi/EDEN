import 'dart:async';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/geo.dart';
import '../../domain/errors.dart';
import '../../domain/models/fare_estimate.dart';
import '../../domain/models/place.dart';
import '../../domain/models/rules_config.dart';
import '../../domain/models/session.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/wallet.dart';
import '../../domain/models/wallet_transaction.dart';
import '../../domain/rules/cancellation.dart';
import '../../domain/rules/pricing.dart';
import '../../domain/rules/wallet_check.dart';
import '../repositories.dart';

/// Interrupteurs de simulation (écran Profil > Mode démo) pour tester
/// les cas limites sans backend.
class SimulationSettings {
  bool noDriverAvailable = false;
  bool forceFareOverrun = false;
  bool eligibleForEmergencyCredit = false;
  bool platformCreditSuspended = false;
}

/// HYPOTHÈSES de la simulation (le vrai calcul est fait par le module Geo
/// du backend sur l'itinéraire routier réel) :
/// - distance routière ≈ distance à vol d'oiseau × 1,3 ;
/// - vitesse moyenne en ville ≈ 20 km/h.
const double _detourFactor = 1.3;
const double _avgSpeedKmh = 20;

double estimateRoadDistanceKm(LatLng a, LatLng b) => haversineKm(a, b) * _detourFactor;

int estimateDurationMin(double km) => math.max(1, (km / _avgSpeedKmh * 60).ceil());

/// Faux backend en mémoire. Implémente les 3 contrats pour que toute
/// l'application soit utilisable et testable AVANT l'API NestJS.
class MockBackend implements AuthRepository, WalletRepository, TripRepository {
  MockBackend({AppRulesConfig? rules, DateTime Function()? clock})
      : rules = rules ?? AppConfig.demoRules,
        _now = clock ?? DateTime.now;

  final AppRulesConfig rules;
  final DateTime Function() _now;
  final SimulationSettings sim = SimulationSettings();
  final math.Random _rng = math.Random();

  static const _demoDriver = DriverInfo(
    name: 'Chauffeur Démo',
    rating: 4.8,
    vehicleModel: 'Véhicule de démonstration',
    plate: 'DEMO-001',
  );

  Session? _session;
  int _balance = 0; // CdC §2.2 : wallet créé avec un solde de 0
  DateTime? _lastEmergencyCreditUse;
  final List<WalletTransaction> _ledger = [];
  final Map<String, Trip> _trips = {};
  final Map<String, Timer> _timers = {};
  final List<String> incidentsLog = [];
  int _seq = 0;

  final _walletCtrl = StreamController<Wallet>.broadcast();
  final _ledgerCtrl = StreamController<List<WalletTransaction>>.broadcast();
  final _tripCtrl = StreamController<Trip>.broadcast();
  final _historyCtrl = StreamController<List<Trip>>.broadcast();

  String _newId(String prefix) => '$prefix-${++_seq}';

  Future<void> _latency([int ms = 400]) => Future.delayed(Duration(milliseconds: ms));

  // ---------------------------------------------------------------- Auth

  @override
  Future<void> requestOtp(String phone) => _latency();

  @override
  Future<Session> verifyOtp(String phone, String code) async {
    await _latency();
    if (code.trim() != AppConfig.demoOtpCode) {
      throw const AppException('err_otp_invalid');
    }
    return _session = Session(userId: 'user-demo', phone: phone);
  }

  @override
  Future<Session> giveConsent() async {
    await _latency(200);
    return _session = _requireSession().copyWith(consentAt: _now());
  }

  @override
  Future<Session> updateEmergencyContact(String phone) async {
    await _latency(200);
    return _session = _requireSession().copyWith(emergencyContactPhone: phone);
  }

  @override
  Future<void> logout() async {
    _session = null;
  }

  Session _requireSession() {
    final s = _session;
    if (s == null) throw const AppException('err_generic');
    return s;
  }

  // -------------------------------------------------------------- Wallet

  Wallet get _wallet => Wallet(
        balance: _balance,
        emergencyCreditStatus: _creditStatus(),
        platformCreditSuspended: sim.platformCreditSuspended,
      );

  EmergencyCreditStatus _creditStatus() {
    final last = _lastEmergencyCreditUse;
    if (last != null && _now().difference(last) < rules.emergencyCredit.usageWindow) {
      return EmergencyCreditStatus.usedThisWeek;
    }
    // En production : décidé par le backend à partir du trust score.
    return sim.eligibleForEmergencyCredit
        ? EmergencyCreditStatus.eligible
        : EmergencyCreditStatus.notEligible;
  }

  /// À appeler après avoir modifié `sim` depuis l'écran de démo.
  void notifySimulationChanged() => _walletCtrl.add(_wallet);

  @override
  Stream<Wallet> watchWallet() async* {
    yield _wallet;
    yield* _walletCtrl.stream;
  }

  @override
  Stream<List<WalletTransaction>> watchTransactions() async* {
    yield List.unmodifiable(_ledger);
    yield* _ledgerCtrl.stream;
  }

  @override
  Future<WalletTransaction> recharge({
    required MobileMoneyOperator operator,
    required String payerPhone,
    required int amount,
  }) async {
    if (amount < AppConfig.minRechargeAmount) {
      throw const AppException('err_recharge_amount');
    }
    // Simule l'attente de validation par code PIN sur le téléphone.
    await _latency(2500);
    return _record(TransactionType.recharge, amount, operator: operator);
  }

  @override
  Future<WalletCheckResult> checkWallet(int estimatedPrice) async {
    await _latency(200);
    return checkWalletForTrip(
      wallet: _wallet,
      estimatedPrice: estimatedPrice,
      config: rules.emergencyCredit,
    );
  }

  /// Ajoute une ligne au ledger (jamais de modification d'une ligne existante).
  WalletTransaction _record(
    TransactionType type,
    int signedAmount, {
    String? tripId,
    MobileMoneyOperator? operator,
  }) {
    _balance += signedAmount;
    final tx = WalletTransaction(
      id: _newId('tx'),
      type: type,
      amount: signedAmount,
      balanceAfter: _balance,
      createdAt: _now(),
      tripId: tripId,
      operator: operator,
    );
    _ledger.insert(0, tx);
    _ledgerCtrl.add(List.unmodifiable(_ledger));
    _walletCtrl.add(_wallet);
    return tx;
  }

  // --------------------------------------------------------------- Trips

  @override
  Future<AppRulesConfig> fetchConfig() async => rules;

  @override
  Future<FareEstimate> estimate(Place pickup, Place destination) async {
    await _latency();
    final km = estimateRoadDistanceKm(pickup.position, destination.position);
    return FareEstimate(
      distanceKm: km,
      durationMin: estimateDurationMin(km),
      price: computeFare(distanceKm: km, config: rules.pricing),
    );
  }

  @override
  Future<Trip> requestTrip({
    required Place pickup,
    required Place destination,
    required FareEstimate estimate,
    required bool useEmergencyCredit,
  }) async {
    await _latency();
    // Le backend refait TOUJOURS la vérification (ne jamais faire confiance
    // au client).
    final check = checkWalletForTrip(
      wallet: _wallet,
      estimatedPrice: estimate.price,
      config: rules.emergencyCredit,
    );
    if (check.decision == WalletDecision.refused) {
      throw const AppException('err_wallet_refused');
    }
    if (check.decision == WalletDecision.emergencyCredit && !useEmergencyCredit) {
      throw const AppException('err_wallet_refused');
    }
    final trip = Trip(
      id: _newId('trip'),
      pickup: pickup,
      destination: destination,
      status: TripStatus.searching,
      estimate: estimate,
      createdAt: _now(),
      paidWithEmergencyCredit: check.decision == WalletDecision.emergencyCredit,
    );
    _save(trip);
    _scheduleMatching(trip.id);
    return trip;
  }

  @override
  Stream<Trip> watchTrip(String tripId) async* {
    final current = _trips[tripId];
    if (current == null) throw const AppException('err_trip_not_found');
    yield current;
    yield* _tripCtrl.stream.where((t) => t.id == tripId);
  }

  @override
  Stream<List<Trip>> watchHistory() async* {
    yield _history();
    yield* _historyCtrl.stream;
  }

  List<Trip> _history() {
    final list = _trips.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  @override
  Future<CancellationQuote> quoteCancellation(String tripId) async {
    final t = _requireTrip(tripId);
    return computeCancellationQuote(
      status: t.status,
      acceptedAt: t.acceptedAt,
      now: _now(),
      config: rules.cancellation,
    );
  }

  @override
  Future<Trip> cancelTrip(String tripId) async {
    await _latency(300);
    final t = _requireTrip(tripId);
    final quote = computeCancellationQuote(
      status: t.status,
      acceptedAt: t.acceptedAt,
      now: _now(),
      config: rules.cancellation,
    );
    if (quote.outcome == CancellationOutcome.notAllowed) {
      throw const AppException('err_cancel_not_allowed');
    }
    _timers.remove(tripId)?.cancel();
    if (quote.fee > 0) {
      _record(TransactionType.cancellationFee, -quote.fee, tripId: tripId);
    }
    return _save(t.copyWith(
      status: TripStatus.cancelledByPassenger,
      cancellationFee: quote.fee,
    ));
  }

  @override
  Future<void> rateTrip(String tripId, int stars, String? comment) async {
    if (stars < 1 || stars > 5) throw ArgumentError.value(stars, 'stars');
    await _latency(200);
    _save(_requireTrip(tripId).copyWith(rating: stars, ratingComment: comment));
  }

  @override
  Future<void> sendSos(String tripId) async {
    await _latency(200);
    incidentsLog.add('SOS trip=$tripId at=${_now().toIso8601String()}');
  }

  @override
  Future<void> reportIssue(String tripId, String message) async {
    await _latency(200);
    incidentsLog.add('ISSUE trip=$tripId msg=$message');
  }

  // ------------------------------------------------- Simulation de course

  Trip _requireTrip(String id) {
    final t = _trips[id];
    if (t == null) throw const AppException('err_trip_not_found');
    return t;
  }

  Trip _save(Trip next) {
    final prev = _trips[next.id];
    if (prev != null && prev.status != next.status) {
      assert(
        canTransition(prev.status, next.status),
        'Transition interdite : ${prev.status} -> ${next.status}',
      );
    }
    _trips[next.id] = next;
    _tripCtrl.add(next);
    _historyCtrl.add(_history());
    return next;
  }

  void _scheduleMatching(String id) {
    final delay = sim.noDriverAvailable ? rules.searchTimeout : const Duration(seconds: 6);
    _timers[id] = Timer(delay, () {
      final t = _trips[id];
      if (t == null || t.status != TripStatus.searching) return;
      if (sim.noDriverAvailable) {
        _save(t.copyWith(status: TripStatus.noDriverFound));
        return;
      }
      // Le chauffeur démarre à ~1,5 km du point de prise en charge.
      final start = LatLng(t.pickup.position.latitude + 0.010, t.pickup.position.longitude + 0.008);
      _save(t.copyWith(
        status: TripStatus.driverAssigned,
        driver: _demoDriver,
        driverPosition: start,
        acceptedAt: _now(),
      ));
      _drive(id, from: start, to: t.pickup.position, steps: 15, onArrive: () => _onDriverArrived(id));
    });
  }

  void _onDriverArrived(String id) {
    final t = _trips[id];
    if (t == null || t.status != TripStatus.driverAssigned) return;
    _save(t.copyWith(status: TripStatus.driverArrived));
    _timers[id] = Timer(const Duration(seconds: 5), () {
      final t2 = _trips[id];
      if (t2 == null || t2.status != TripStatus.driverArrived) return;
      _save(t2.copyWith(status: TripStatus.inProgress, startedAt: _now()));
      _drive(id,
          from: t2.pickup.position,
          to: t2.destination.position,
          steps: 25,
          onArrive: () => _completeTrip(id));
    });
  }

  /// Déplace le chauffeur en ligne droite, une position par seconde.
  void _drive(
    String id, {
    required LatLng from,
    required LatLng to,
    required int steps,
    required void Function() onArrive,
  }) {
    var i = 0;
    _timers[id]?.cancel();
    _timers[id] = Timer.periodic(const Duration(seconds: 1), (timer) {
      final t = _trips[id];
      if (t == null ||
          !(t.status == TripStatus.driverAssigned || t.status == TripStatus.inProgress)) {
        timer.cancel();
        return;
      }
      i++;
      _save(t.copyWith(driverPosition: interpolate(from, to, i / steps)));
      if (i >= steps) {
        timer.cancel();
        onArrive();
      }
    });
  }

  void _completeTrip(String id) {
    final t = _trips[id];
    if (t == null || t.status != TripStatus.inProgress) return;
    // Le prix final réel est recalculé par le backend sur le trajet réel.
    // Simulation : estimation + 0 à 15 %, ou +40 % si on force le dépassement.
    final factor = sim.forceFareOverrun ? 1.4 : 1.0 + _rng.nextDouble() * 0.15;
    final finalPrice = math.max((t.estimate.price * factor).round(), rules.pricing.minimumFare);
    _record(TransactionType.tripPayment, -finalPrice, tripId: id);
    if (t.paidWithEmergencyCredit) {
      _lastEmergencyCreditUse = _now();
      _walletCtrl.add(_wallet);
    }
    _save(t.copyWith(
      status: TripStatus.completed,
      finalPrice: finalPrice,
      completedAt: _now(),
    ));
  }

  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _walletCtrl.close();
    _ledgerCtrl.close();
    _tripCtrl.close();
    _historyCtrl.close();
  }
}
