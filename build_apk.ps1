# Construit l'APK Android installable de l'application passager TACO EDEN.
# Lancement : double-clic sur build_apk.bat (ou : powershell -ExecutionPolicy Bypass -File build_apk.ps1)
# Prerequis : Flutter + Android Studio (Android SDK) installes ; "flutter doctor" sans croix rouge cote Android.

Set-Location $PSScriptRoot

function Run-Step([string]$title, [scriptblock]$block, [bool]$fatal = $true) {
    Write-Host ""
    Write-Host "==> $title" -ForegroundColor Cyan
    & $block
    if ($LASTEXITCODE -ne 0) {
        if ($fatal) {
            Write-Host "ECHEC : $title (code $LASTEXITCODE). Lisez le message ci-dessus." -ForegroundColor Red
            Read-Host "Appuyez sur Entree pour fermer"
            exit 1
        } else {
            Write-Host "Attention : $title a signale des problemes (on continue)." -ForegroundColor Yellow
        }
    }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter est introuvable. Installez-le : https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Red
    Read-Host "Appuyez sur Entree pour fermer"
    exit 1
}

Run-Step "Version de Flutter" { flutter --version }

if (-not (Test-Path "android")) {
    Run-Step "Generation des dossiers android/ ios/ web/ (lib/ et test/ ne sont pas modifies)" {
        flutter create --org cm.tacoeden --project-name eden_mobility_passager --platforms android,ios,web .
    }
}

Run-Step "Telechargement des dependances" { flutter pub get }
Run-Step "Generation des icones a partir du logo" { dart run flutter_launcher_icons }
Run-Step "Permissions GPS, bouton SOS et nom de l'application" { dart run tool/prepare_platforms.dart }
Run-Step "Analyse du code (les erreurs bloquent, pas les avertissements)" { flutter analyze --no-fatal-infos --no-fatal-warnings }
Run-Step "Tests automatiques" { flutter test } $false
Run-Step "Construction de l'APK (quelques minutes la 1re fois)" { flutter build apk --release }

$apk = "build\app\outputs\flutter-apk\app-release.apk"
$dest = Join-Path (Split-Path $PSScriptRoot -Parent) "TACO_EDEN_passager.apk"
Copy-Item $apk $dest -Force

Write-Host ""
Write-Host "APK pret : $dest" -ForegroundColor Green
Write-Host "Copiez-le sur le telephone (cable USB, WhatsApp, Google Drive...) puis ouvrez-le."
Write-Host "Android demandera d'autoriser l'installation d'applications de source inconnue."
Read-Host "Appuyez sur Entree pour fermer"
