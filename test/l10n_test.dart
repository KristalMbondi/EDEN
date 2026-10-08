import 'package:eden_mobility_passager/core/l10n/strings.dart';
import 'package:eden_mobility_passager/domain/models/trip.dart';
import 'package:eden_mobility_passager/domain/models/wallet.dart';
import 'package:eden_mobility_passager/domain/models/wallet_transaction.dart';
import 'package:eden_mobility_passager/domain/rules/wallet_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FR et EN ont exactement les mêmes clés', () {
    final fr = appStrings['fr']!.keys.toSet();
    final en = appStrings['en']!.keys.toSet();
    expect(fr.difference(en), isEmpty, reason: 'Clés manquantes en anglais');
    expect(en.difference(fr), isEmpty, reason: 'Clés manquantes en français');
  });

  test('chaque valeur d\'enum affichée a sa traduction', () {
    final keys = <String>[
      for (final s in TripStatus.values) 'status_${s.name}',
      for (final r in RefusalReason.values) 'refusal_${r.name}',
      for (final c in EmergencyCreditStatus.values) 'credit_${c.name}',
      for (final t in TransactionType.values) 'tx_${t.name}',
      for (final o in MobileMoneyOperator.values) 'op_${o.name}',
    ];
    for (final k in keys) {
      expect(appStrings['fr']!.containsKey(k), isTrue, reason: k);
    }
  });
}
