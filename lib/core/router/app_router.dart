import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/consent_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/phone_screen.dart';
import '../../features/booking/estimate_screen.dart';
import '../../features/booking/searching_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/history/receipt_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/trip/trip_end_screen.dart';
import '../../features/trip/trip_tracking_screen.dart';
import '../../features/wallet/recharge_screen.dart';
import '../../features/wallet/wallet_screen.dart';
import '../../providers.dart';

/// Carte de navigation de l'application passager.
///
///  /login → /otp → /consent → /home (onglets : home, history, wallet, profile)
///  /home → /estimate → /searching/:id → /trip/:id → /trip/:id/end
final routerProvider = Provider<GoRouter>((ref) {
  // Relance les redirections à chaque connexion / déconnexion.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      final inAuthFlow = loc == '/login' || loc == '/otp';

      if (session == null) return inAuthFlow ? null : '/login';
      if (!session.consentGiven) return loc == '/consent' ? null : '/consent';
      if (inAuthFlow || loc == '/consent') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const PhoneScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(phone: state.uri.queryParameters['phone'] ?? ''),
      ),
      GoRoute(path: '/consent', builder: (_, __) => const ConsentScreen()),

      // Onglets principaux avec barre de navigation en bas.
      ShellRoute(
        builder: (context, state, child) => MainShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // Écrans plein écran (sans barre d'onglets).
      GoRoute(path: '/wallet/recharge', builder: (_, __) => const RechargeScreen()),
      GoRoute(
        path: '/history/:id',
        builder: (_, state) => ReceiptScreen(tripId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/estimate', builder: (_, __) => const EstimateScreen()),
      GoRoute(
        path: '/searching/:id',
        builder: (_, state) => SearchingScreen(tripId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (_, state) => TripTrackingScreen(tripId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trip/:id/end',
        builder: (_, state) => TripEndScreen(tripId: state.pathParameters['id']!),
      ),
    ],
  );
});
