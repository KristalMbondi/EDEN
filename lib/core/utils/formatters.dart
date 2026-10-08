/// Formate un montant entier en FCFA : 12500 -> "12 500 FCFA".
/// Séparateur de milliers : espace fine insécable (U+202F), usage français.
String formatXaf(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer FCFA';
}

/// "08/10/2026 10:41" (sans dépendre du package intl).
String formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String formatKm(double km) => '${km.toStringAsFixed(1)} km';

/// Valide un numéro mobile camerounais saisi SANS l'indicatif +237 :
/// 9 chiffres commençant par 6. Les espaces sont ignorés.
/// (Plan de numérotation à reconfirmer auprès de l'ART si besoin.)
String? normalizeCameroonMobile(String input) {
  var s = input.replaceAll(RegExp(r'\s'), '');
  if (s.startsWith('+237')) s = s.substring(4);
  if (s.startsWith('00237')) s = s.substring(5);
  return RegExp(r'^6\d{8}$').hasMatch(s) ? s : null;
}
