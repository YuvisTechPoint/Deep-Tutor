# Production release APK for DeepTutor Android.
# Requires: Flutter SDK, Android SDK, JDK keytool.
# Output: build/app/outputs/flutter-apk/app-release.apk

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $Root

$KeyProps = Join-Path $Root "android\key.properties"
$Keystore = Join-Path $Root "android\app\upload-keystore.jks"

if (-not (Test-Path $KeyProps)) {
    Write-Host "Generating release keystore (first run only)..."
    $pass = "DeeptutorMobileRelease!"
    & keytool -genkeypair -v `
        -keystore $Keystore `
        -storetype JKS `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -alias upload `
        -storepass $pass `
        -keypass $pass `
        -dname "CN=DeepTutor, OU=Mobile, O=DeepTutor, L=Unknown, ST=Unknown, C=US"
    @"
storePassword=$pass
keyPassword=$pass
keyAlias=upload
storeFile=app/upload-keystore.jks
"@ | Set-Content -Path $KeyProps -Encoding UTF8
    Write-Host "Created android/key.properties and upload-keystore.jks — back up these files for Play Store updates."
}

flutter pub get
flutter build apk --release `
    --dart-define=APP_FLAVOR=prod `
    @args

$apk = Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
    $item = Get-Item $apk
    Write-Host ""
    Write-Host "Release APK ready:" -ForegroundColor Green
    Write-Host "  $($item.FullName)"
    Write-Host "  $([math]::Round($item.Length / 1MB, 2)) MB"
}
