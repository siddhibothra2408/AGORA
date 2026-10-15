#!/usr/bin/env bash
# Agora Demo Startup Script (Bash)
# Starts Firebase Emulators, awaits readiness, and seeds the 4-account Capstone demo

set -euo pipefail

FIXTURE_MODE="${1:-}"

echo "=========================================================="
echo " Agora Phase 5 Demo Runner (Local Emulator Environment)   "
echo "=========================================================="

if [ "$FIXTURE_MODE" = "--fixture" ] || [ "${AI_PROVIDER:-}" = "fixture" ]; then
  export AI_PROVIDER="fixture"
  echo "[AI PROVIDER] FIXTURE MODE ACTIVE (Offline demo fallback)"
else
  export AI_PROVIDER="gemini"
  echo "[AI PROVIDER] LIVE GEMINI MODE ACTIVE (Server-side callable)"
fi

export FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
export FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"

echo ""
echo "[1/4] Starting Firebase Emulator Suite in background..."
npx firebase emulators:start &
EMULATOR_PID=$!

echo ""
echo "[2/4] Waiting for Firestore emulator readiness..."
until curl -s "http://127.0.0.1:8080" > /dev/null 2>&1; do
  sleep 1
done
echo "Emulators ready."

echo ""
echo "[3/4] Running seed script..."
(cd functions && npm run seed:demo)

echo ""
echo "[4/4] Device Connection Instructions:"
echo "----------------------------------------------------------"
echo "A. Android Virtual Device (AVD Emulator):"
echo "   Connects via 10.0.2.2 loopback:"
echo "   flutter run -d <emulator-id> --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2"
echo ""
echo "B. Physical Android Phone (USB):"
echo "   1. Reverse ports: adb reverse tcp:9099 tcp:9099 && adb reverse tcp:8080 tcp:8080 && adb reverse tcp:5001 tcp:5001"
echo "   2. Run app:       flutter run -d <phone-id> --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1"
echo ""
echo "C. Google Chrome (Host Web Browser - Zero Android SDK required):"
echo "   flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=localhost"
echo "----------------------------------------------------------"
echo "Seeded Demo Accounts (Password: AgoraDemo2026!):"
echo "  - Maya Lin (Admin): maya@agora.demo  (Consent: Consented)"
echo "  - Ravi Patel:       ravi@agora.demo  (Consent: Consented)"
echo "  - Lena Kim:         lena@agora.demo  (Consent: Consented)"
echo "  - Sam Chen:         sam@agora.demo   (Consent: WITHHELD / Shield Active)"
echo "=========================================================="

wait $EMULATOR_PID
