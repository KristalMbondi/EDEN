import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'strings.dart';

/// Localisation FR / EN volontairement simple (pas de génération de code) :
/// toutes les chaînes sont dans `strings.dart`. Un test unitaire vérifie que
/// le français et l'anglais ont exactement les mêmes clés.
///
/// Usage dans un widget :  Text(context.tr('home_order'))
/// Avec paramètre :        context.tr('wallet_balance', {'amount': '1 000'})
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('fr'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(l != null, 'AppLocalizations.delegate absent de MaterialApp');
    return l!;
  }

  String t(String key, [Map<String, String> params = const {}]) {
    final table = appStrings[locale.languageCode] ?? appStrings['fr']!;
    var text = table[key] ?? key; // clé affichée si traduction manquante
    params.forEach((name, value) {
      text = text.replaceAll('{$name}', value);
    });
    return text;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => appStrings.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  String tr(String key, [Map<String, String> params = const {}]) =>
      AppLocalizations.of(this).t(key, params);
}
