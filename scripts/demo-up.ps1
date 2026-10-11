# Agora Demo Startup Script (Windows PowerShell)
# Starts Firebase Emulators, awaits readiness, and seeds the 4-account Capstone demo

param (
    [switch]$FixtureMode = $false
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Agora Phase 5 Demo Runner (Local Emulator Environment)   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Environment & Provider Mode
if ($FixtureMode) {
    $env:AI_PROVIDER = "fixture"
    Write-Host "[AI PROVIDER] FIXTURE MODE ACTIVE (Offline demo fallback)" -ForegroundColor Yellow
} else {
    $env:AI_PROVIDER = "gemini"
    Write-Host "[AI PROVIDER] LIVE GEMINI MODE ACTIVE (Server-side callable)" -ForegroundColor Green
}

# 2. Set Emulator Environment Variables for Seed Verification
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099"

Write-Host "`n[1/4] Starting Firebase Emulator Suite..." -ForegroundColor Yellow
Write-Host "  - Auth:      http://127.0.0.1:9099"
Write-Host "  - Firestore: http://127.0.0.1:8080"
Write-Host "  - Functions: http://127.0.0.1:5001"
Write-Host "  - UI:        http://127.0.0.1:4000"

# Launch emulators in a separate window
Start-Process powershell -ArgumentList "-NoExit", "-Command", "npx firebase emulators:start"

Write-Host "`n[2/4] Awaiting Emulator Readiness..." -ForegroundColor Yellow
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:8080" -TimeoutSec 1 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 404 -or $response.StatusCode -eq 400) {
            $ready = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 1
    }
}

if (-not $ready) {
    Write-Host "Notice: Proceeding with seed script once emulator finishes booting." -ForegroundColor Gray
}

Write-Host "`n[3/4] Seeding Demo Database..." -ForegroundColor Yellow
Push-Location functions
try {
    npm run seed:demo
    Write-Host "Seed completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Note: If Node/npm is not installed, install Node 20+ and run 'npm run seed:demo' inside functions/." -ForegroundColor Red
} finally {
    Pop-Location
}

Write-Host "`n[4/4] Device Connection Instructions:" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------"
Write-Host "A. Android Virtual Device (AVD Emulator):" -ForegroundColor White
Write-Host "   Connects via 10.0.2.2 loopback."
Write-Host "   Command:" -ForegroundColor Gray
Write-Host "   flutter run -d <emulator-id> --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2"
Write-Host ""
Write-Host "B. Physical Android Phone (Connected via USB):" -ForegroundColor White
Write-Host "   1. Reverse emulator ports to localhost:"
Write-Host "      adb reverse tcp:9099 tcp:9099" -ForegroundColor Gray
Write-Host "      adb reverse tcp:8080 tcp:8080" -ForegroundColor Gray
Write-Host "      adb reverse tcp:5001 tcp:5001" -ForegroundColor Gray
Write-Host "   2. Launch Flutter with host 127.0.0.1:"
Write-Host "      flutter run -d <phone-id> --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1"
Write-Host "----------------------------------------------------------"
Write-Host "Seeded Demo Accounts (Password: AgoraDemo2026!):" -ForegroundColor White
Write-Host "  - Maya Lin (Admin): maya@agora.demo  (Consent: Consented)"
Write-Host "  - Ravi Patel:       ravi@agora.demo  (Consent: Consented)"
Write-Host "  - Lena Kim:         lena@agora.demo  (Consent: Consented)"
Write-Host "  - Sam Chen:         sam@agora.demo   (Consent: WITHHELD / Shield Active)"
Write-Host "==========================================================" -ForegroundColor Cyan
