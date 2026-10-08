// Prépare les dossiers générés par `flutter create` :
//  - Android : permissions (Internet, GPS), requête tel: (bouton SOS),
//    nom affiché sous l'icône = "TACO EDEN" ;
//  - iOS : message d'autorisation GPS et nom affiché.
//
// Usage : dart run tool/prepare_platforms.dart
// Le script est idempotent : on peut le relancer sans dupliquer les lignes.

import 'dart:io';

const appLabel = 'TACO EDEN';

void main() {
  _android();
  _ios();
}

void _android() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    stderr.writeln('Dossier android/ absent : lancez d\'abord "flutter create".');
    exitCode = 1;
    return;
  }
  var xml = file.readAsStringSync();

  const permissions = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
  ];
  for (final p in permissions) {
    if (!xml.contains('"$p"')) {
      xml = xml.replaceFirst(
        '<application',
        '<uses-permission android:name="$p"/>\n    <application',
      );
    }
  }

  const telIntent = '<intent>\n'
      '            <action android:name="android.intent.action.VIEW"/>\n'
      '            <data android:scheme="tel"/>\n'
      '        </intent>';
  if (!xml.contains('android:scheme="tel"')) {
    if (xml.contains('<queries>')) {
      xml = xml.replaceFirst('<queries>', '<queries>\n        $telIntent');
    } else {
      xml = xml.replaceFirst(
        '</manifest>',
        '    <queries>\n        $telIntent\n    </queries>\n</manifest>',
      );
    }
  }

  xml = xml.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="$appLabel"');
  file.writeAsStringSync(xml);
  stdout.writeln('Android : permissions GPS/Internet, requête tel: et nom "$appLabel" appliqués.');
}

void _ios() {
  final file = File('ios/Runner/Info.plist');
  if (!file.existsSync()) return;
  var plist = file.readAsStringSync();

  if (!plist.contains('NSLocationWhenInUseUsageDescription')) {
    plist = plist.replaceFirst(
      '<dict>',
      '<dict>\n'
          '\t<key>NSLocationWhenInUseUsageDescription</key>\n'
          '\t<string>Votre position sert à trouver un chauffeur et à suivre la course.</string>',
    );
  }
  plist = plist.replaceFirstMapped(
    RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)'),
    (m) => '${m[1]}$appLabel${m[2]}',
  );
  file.writeAsStringSync(plist);
  stdout.writeln('iOS : autorisation GPS et nom "$appLabel" appliqués.');
}
