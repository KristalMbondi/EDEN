import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';

/// Barre d'onglets : Accueil / Courses / Wallet / Profil.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = ['/home', '/history', '/wallet', '/profile'];

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere((t) => location.startsWith(t));
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.map_outlined), label: context.tr('tab_home')),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), label: context.tr('tab_history')),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), label: context.tr('tab_wallet')),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: context.tr('tab_profile')),
        ],
      ),
    );
  }
}
