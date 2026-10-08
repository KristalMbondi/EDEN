# EDEN Mobility — Application passager (Flutter)

Application mobile **passager** du service VTC de TACO EDEN MOBILITY, construite à partir du **cahier des charges v1.0 (10/08/2026)** : inscription par OTP, wallet prépayé (Orange Money / MTN MoMo), crédit d'urgence, commande de course, suivi temps réel, SOS, fin de course avec notation, historique et reçus. Bilingue **français / anglais**.

Elle fonctionne **dès maintenant, sans backend**, grâce à un faux serveur en mémoire (`MockBackend`). Le jour où l'API NestJS existe, on remplace 3 providers. Aucun écran ne change.

> ⚠️ **Tous les montants (tarifs, plafonds, frais) sont FICTIFS** : le CdC (§9) n'en fixe aucun. Voir `lib/core/config/app_config.dart`.
> 📄 Spécification, contrat API proposé et **12 points ouverts du CdC** : [`docs/SPEC_APP_PASSAGER.md`](docs/SPEC_APP_PASSAGER.md).

---

## 1. Démarrer (Windows)

Versions supposées : **Flutter ≥ 3.22 / Dart ≥ 3.4**. Paquets : `flutter_launcher_icons ^0.13.1` (icônes), `flutter_riverpod ^2.5.1`, `go_router ^14.2.0`, `flutter_map ^7.0.2`, `latlong2 ^0.9.1`, `geolocator ^13.0.1`, `url_launcher ^6.3.0`.

```powershell
cd eden_mobility_passager
flutter --version                 # vérifier la version
flutter create --org cm.tacoeden --project-name eden_mobility_passager --platforms android,ios,web .   # génère android/, ios/, web/ (ne remplace pas lib/ ni test/)
flutter pub get
dart run flutter_launcher_icons          # icônes à partir du logo
dart run tool/prepare_platforms.dart     # permissions GPS + SOS, nom « TACO EDEN »
flutter analyze                   # doit afficher 0 erreur (quelques "info" de style sont possibles)
flutter test                      # règles métier + traductions + faux backend + test de fumée
flutter run -d chrome             # le plus simple pour commencer
# ou : flutter run   (émulateur Android / téléphone branché)
```

**Ce code n'a pas pu être compilé là où il a été écrit** (pas de SDK Flutter disponible). La syntaxe des 44 fichiers Dart a été contrôlée avec un analyseur, ainsi que les clés de traduction, les imports et les valeurs attendues des tests. Mais seul `flutter analyze` peut garantir l'absence d'erreur de type. **Lance-le en premier.** Si une erreur apparaît, c'est probablement une API de paquet qui a changé de version (voir §6).

## 1 bis. Obtenir l'APK Android à installer

Les permissions GPS, l'appel du bouton SOS, le nom « TACO EDEN » et les icônes tirées du logo (`assets/branding/`) sont appliqués **automatiquement**. Il n'y a rien à modifier à la main.

**Option A — sur ton PC** (il faut Flutter **et** Android Studio ; `flutter doctor` ne doit afficher aucune croix rouge côté Android) :
double-clic sur **`build_apk.bat`**. Le script génère les dossiers de plateforme, les icônes et les permissions, puis lance l'analyse, les tests et la construction. À la fin, **`TACO_EDEN_passager.apk`** apparaît dans le dossier `TEM`. Compte 5 à 15 min la première fois (téléchargement de Gradle).

**Option B — dans le cloud GitHub** (rien à installer) : pousse ce dossier dans un dépôt GitHub, puis va dans *Actions › Build APK › Run workflow*. Après 5 à 10 min, télécharge l'artefact `taco-eden-passager-apk`. Le workflow est dans `.github/workflows/build-apk.yml`.

**Installer sur le téléphone :** copie l'APK (câble USB, WhatsApp, Google Drive…), ouvre-le et autorise l'installation depuis une source inconnue.

> Cet APK est signé avec la **clé de debug** de Flutter. Il convient pour des tests internes, pas pour le Play Store : pour une publication, il faudra une clé de signature propre à l'entreprise (fichier keystore, à conserver précieusement) et un bundle `flutter build appbundle`.

## 2. Parcours de démo (5 minutes)

1. Numéro : `699 00 00 00` → code **123456** → accepter le consentement.
2. **Wallet › Recharger** 5 000 FCFA (MTN ou Orange, validé en 2,5 s).
3. **Accueil** : toucher la carte (ou « Où allez-vous ? » → *Bastos*) → **Commander** → **Confirmer**.
4. Chauffeur trouvé en ~6 s → suivi sur la carte → arrivée → course → **note**.
5. **Profil › Mode démo** : teste les cas limites (aucun chauffeur → timeout 60 s, dépassement > 30 %, crédit d'urgence, suspension globale).

Astuce crédit d'urgence : wallet à 0 + « Éligible au crédit d'urgence » + une course < 2 000 FCFA → le crédit est proposé → après la course, solde négatif = compte bloqué → recharger débloque.

## 3. Architecture

```
lib/
├── main.dart, app.dart          # ProviderScope + MaterialApp.router (thème, FR/EN)
├── providers.dart               # tous les providers Riverpod
├── core/
│   ├── config/app_config.dart   # useMock, valeurs FICTIVES, lieux de démo
│   ├── l10n/                    # traductions FR/EN (strings.dart) + délégué
│   ├── router/app_router.dart   # routes + redirections (connexion, consentement)
│   ├── theme/app_theme.dart
│   └── utils/                   # formatage FCFA/dates, validation n°, géo
├── domain/                      # PUR DART : aucune dépendance Flutter
│   ├── models/                  # Trip (+ machine à états), Wallet, Session…
│   └── rules/                   # pricing, annulation, vérification wallet
├── data/
│   ├── repositories.dart        # CONTRATS (interfaces) Auth / Wallet / Trip
│   └── mock/mock_backend.dart   # faux serveur + simulation de course
└── features/                    # un dossier par écran
    ├── auth/  home/  booking/  trip/  wallet/  history/  profile/  shell/  common/
test/                            # rules_test, l10n_test, mock_backend_test, widget_test
docs/SPEC_APP_PASSAGER.md
```

Trois idées à retenir :
- **`domain/` ne dépend de rien** : les règles du CdC sont testables en millisecondes, sans émulateur.
- **Les écrans ne connaissent que les interfaces** de `repositories.dart`. On peut donc passer du mock à l'API sans les toucher.
- **Le backend décide, l'app affiche.** Le prix, les frais et l'éligibilité au crédit sont toujours recalculés côté serveur.

## 4. Brancher la vraie API (plus tard)

1. Ajouter `http` (ou `dio`) et `socket_io_client` au `pubspec.yaml`.
2. Créer `lib/data/api/` avec `ApiAuthRepository`, `ApiWalletRepository`, `ApiTripRepository`, qui implémentent les interfaces. Les endpoints proposés sont dans la SPEC §5.
3. Dans `providers.dart`, faire pointer `authRepositoryProvider` & co vers ces classes quand `AppConfig.useMock == false`.
4. Avant la production, remplacer les tuiles OpenStreetMap publiques (leur politique interdit l'usage intensif) par un fournisseur dédié.

## 5. Exercices (du plus simple au plus ambitieux)

| # | Exercice | Ce que tu apprends |
|---|---|---|
| 1 | Écrire `test/formatters_test.dart` : `formatXaf(-1500)`, `normalizeCameroonMobile('+237 699 00 00 00')`, un numéro qui commence par 2… | Tests unitaires, cas limites |
| 2 | Le texte « plus de 30 % » de l'écran d'estimation est écrit en dur. Le rendre dynamique avec `rulesConfigProvider` (paramètre `{percent}`) | Riverpod `FutureProvider`, i18n paramétrée |
| 3 | Mémoriser la langue choisie et la session avec `shared_preferences` | Persistance locale, cycle de vie |
| 4 | Test de widget de l'écran d'estimation avec `ProviderScope(overrides: [...])` et un `MockBackend` dont `sim.eligibleForEmergencyCredit = true` | Tests de widgets, injection de dépendances |
| 5 | Côté data science : coder le trust score du CdC §2.6 en Python, simuler 1 000 passagers et montrer que `nb_courses_7j / seuil` peut dépasser 1. Proposer une version normalisée **qui inclut l'ancienneté** (absente de la formule) | Analyse critique d'un score, simulation |
| 6 | Mini-backend NestJS avec 2 routes (`POST /trips/estimate`, `POST /trips`) + une passerelle Socket.io qui émet `trip:status`, puis `ApiTripRepository` | Intégration client/serveur temps réel |

## 6. Si `flutter analyze` signale une erreur

- **`withOpacity` deprecated** (Flutter ≥ 3.27) : simple « info ». Remplacer par `withValues(alpha: 0.1)` si tu es sur une version récente.
- **API `flutter_map`** (`initialCameraFit`, `Marker(child:)`, `RichAttributionWidget`) : écrites pour la v7. En v8, voir le guide de migration sur docs.fleaflet.dev.
- **Riverpod 3** : le code utilise `Notifier`/`StreamProvider` de Riverpod 2. La contrainte `^2.5.1` empêche la montée automatique en v3.

## 7. Ressources

- Flutter : installation Windows — https://docs.flutter.dev/get-started/install/windows · chaîne YouTube officielle — https://www.youtube.com/@flutterdev
- Riverpod : https://riverpod.dev · articles pratiques — https://codewithandrea.com
- go_router : https://pub.dev/packages/go_router
- flutter_map : https://docs.fleaflet.dev · politique des tuiles OSM — https://operations.osmfoundation.org/policies/tiles/
- geolocator : https://pub.dev/packages/geolocator
- NestJS : https://docs.nestjs.com (voir « WebSockets › Gateways » pour Socket.io) · Socket.io : https://socket.io/docs/v4/
- PostGIS (recherche de chauffeurs dans un rayon) : https://postgis.net/documentation/
- Paiements : MTN MoMo API — https://momodeveloper.mtn.com · Orange Developer — https://developer.orange.com. **À vérifier : l'offre et les conditions disponibles pour le Cameroun.**

## 8. Générer un APK installable sur Android

L'APK produit est signé avec la **clé de debug** : il s'installe sur n'importe quel téléphone pour les tests (« sources inconnues » à autoriser), mais il **n'est pas publiable sur le Play Store**. Pour publier, il faudra une clé de signature de l'entreprise (keystore), à conserver précieusement.

### Option A — Sans rien installer : GitHub Actions (recommandé)

1. Créer un dépôt **privé** sur github.com, puis y envoyer ce dossier :
   ```powershell
   cd eden_mobility_passager
   git init -b main
   git add .
   git commit -m "App passager EDEN Mobility"
   git remote add origin https://github.com/<ton-compte>/eden_mobility_passager.git
   git push -u origin main
   ```
2. Le workflow `.github/workflows/build-apk.yml` démarre tout seul (~8 à 12 min). Il génère `android/`, ajoute les permissions, puis lance `flutter analyze`, les tests et la compilation.
3. Onglet **Actions** › dernier run › **Artifacts** › `eden-passager-apk` → télécharger, dézipper, envoyer `app-release.apk` sur le téléphone.

Si le run échoue à l'étape `flutter analyze` ou `flutter test`, le journal indique le fichier et la ligne en cause.

### Option B — Sur ton PC (Flutter + Android Studio installés)

```powershell
cd eden_mobility_passager
flutter doctor                     # tout doit être vert pour « Android toolchain »
flutter create --org cm.tacoeden --platforms android .
python tool\patch_android_manifest.py   # ou ajouter les permissions à la main (§1)
flutter pub get
flutter build apk --release
# APK : build\app\outputs\flutter-apk\app-release.apk
# Téléphone branché en USB (débogage USB activé) :
flutter install
```

Astuce : `flutter build apk --split-per-abi` produit des APK plus légers (un par type de processeur ; la plupart des téléphones récents utilisent `arm64-v8a`).
