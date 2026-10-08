// Tests de fumée de la navigation au démarrage.
// (Ce fichier remplace celui que `flutter create` génère par défaut.)

import 'package:eden_mobility_passager/app.dart';
import 'package:eden_mobility_passager/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app(Map<String, Object> prefsValues) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const EdenPassagerApp(),
  );
}

void main() {
  // Langue par défaut des tests Flutter : anglais (en_US).

  testWidgets('premier lancement : écrans d\'introduction, puis connexion', (tester) async {
    await tester.pumpWidget(await _app({}));
    await tester.pumpAndSettle();
    expect(find.text('Book in seconds'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Get the code by SMS'), findsOneWidget);
  });

  testWidgets('introduction déjà vue : arrive directement sur l\'écran téléphone', (tester) async {
    await tester.pumpWidget(await _app({'onboarding_seen': true}));
    await tester.pumpAndSettle();

    expect(find.text('Get the code by SMS'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
