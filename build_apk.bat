@echo off
REM Double-cliquez sur ce fichier pour construire l'APK Android.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_apk.ps1"
