// Test de fumée : l'application démarre et redirige vers la connexion.
// (Ce fichier remplace celui que `flutter create` génère par défaut.)

import 'package:eden_mobility_passager/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('un utilisateur non connecté arrive sur l\'écran téléphone', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EdenPassagerApp()));
    await tester.pumpAndSettle();

    // Langue par défaut des tests Flutter : anglais (en_US).
    expect(find.text('Get the code by SMS'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
