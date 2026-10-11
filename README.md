# Agora (Consent-First Messaging & Collaboration)

> **"Agora is the group chat where AI only reads what you hand it, everyone can see what it was handed, and nothing becomes a task or decision until a human approves it."**

Agora is an Android-first, consent-first mobile collaboration platform built with **Flutter** and **Firebase**. It replaces uninvited, ambient AI bots with human sovereignty, auditable provenance receipts, and explicit consent shields.

---

## Core Product Thesis & Invariants

1. **Zero Ambient AI:** AI has no standing access to background message streams. No bots sit inside your group chat listening.
2. **Human Handoff:** Selected messages are explicitly passed by an authorized human.
3. **Author Consent Shield:** Authors can withhold individual messages or whole accounts from AI. Withheld messages are cryptographically vetoed and excluded *before* reaching any server-side AI model.
4. **Non-Authoritative Proposals:** AI outputs are strictly Proposals. Nothing enters the Board, Focus stream, or task list without human review, edit, or approval.
5. **Verbatim Provenance Receipts:** Accepted items retain immutable links back to their source messages and exact quotation anchors.
6. **Public Audit Ledger:** Every AI handoff produces a permanent record visible to all Space members in the Pulse ledger.
7. **Strict Palette Semantics:** Gold (`#C69214`) is strictly reserved for AI-related UI (proposals, provenance links, AI badges). Deterministic features—**Catch-up**, **Focus**, and **Pulse**—use Aegean Blue, Terracotta, and neutral slate, and never use Gold.
8. **Privacy Transparency:** Agora is **NOT end-to-end encrypted (E2EE)**. Messages reside in Google Cloud Firestore; server-side Cloud Functions invoke Gemini.

---

## Architectural Data Flow

```text
[ Client (Flutter) ]
       │
       │ 1. User selects messages via Lens (Preview excludes withheld messages)
       ▼
[ Cloud Functions Callable: processExplicitHandoff ]
       │
       │ 2. Authenticates user & validates active Space membership
       │ 3. Enforces Author Shield (filters out aiWithheld == true)
       │ 4. Pseudonymizes identifiers & constructs audited payload
       ▼
┌──────────────────────────────┴──────────────────────────────┐
│                                                             │
│ If AI_PROVIDER=fixture             If AI_PROVIDER=gemini    │
│ (Offline Fallback Mode)            (Live Cloud Mode)        │
│                                                             │
│ 5a. Matches against local          5b. Server calls Gemini  │
│     fixtures/demo-extract.json         with JSON schema     │
│                                                             │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               │ 6. Validates proposal schema (Tasks, Decisions, Questions)
                               ▼
[ Non-Authoritative Proposal Store (Firestore) ]
       │
       │ 7. Proposals stored at proposals/{id} (status: 'pending')
       │ 8. Immutable handoff written to spaces/{id}/handoffs/{id}
       │ 9. Immutable audit log written to aiOutputs/{id}
       ▼
[ Private Proposal Tray (Client UI) ]
       │
       │ 10. Human reviews, edits title/dates, dismisses, or approves
       ▼
[ Space Board (Firestore: spaces/{id}/items/{id}) ]
       │
       │ 11. Promoted items store approvedByUid and source message receipts
       ▼
[ Deterministic Multi-Device Sync ]
       │
       ├─► Space Board: Live item list with provenance tags
       ├─► Focus Tab: "Proposed for you" queue with Accept/Decline
       └─► Pulse Tab: 14-day completion sparkline & member load
```

---

## Getting Started & Local Development

### Prerequisites
- **Flutter SDK:** 3.47.5+ (Dart 3.13.4+)
- **Node.js:** v20+ with npm (for Firebase Cloud Functions)
- **Firebase CLI:** `npm install -g firebase-tools`
- **Android SDK & Platform Tools:** `adb` (for Android emulator or USB phone)

### 1. Start Firebase Emulators & Seed Demo Data

#### Windows (PowerShell):
```powershell
# Live Gemini mode (uses GEMINI_API_KEY if configured):
.\scripts\demo-up.ps1

# Offline Fixture mode (replays deterministic proposals, no network required):
.\scripts\demo-fixture.ps1
```

#### macOS / Linux (Bash):
```bash
# Live Gemini mode:
./scripts/demo-up.sh

# Offline Fixture mode:
./scripts/demo-fixture.sh
```

The script boots the local Firebase Emulator Suite on ports:
- **Auth Emulator:** `http://127.0.0.1:9099`
- **Firestore Emulator:** `http://127.0.0.1:8080`
- **Functions Emulator:** `http://127.0.0.1:5001`
- **Emulator UI:** `http://127.0.0.1:4000`

And seeds four accounts with demo password **`AgoraDemo2026!`**:
- `maya@agora.demo` (Space Admin, Consented)
- `ravi@agora.demo` (Member, Consented)
- `lena@agora.demo` (Member, Consented)
- `sam@agora.demo` (Member, **WITHHELD** - author AI shield active)

---

### 2. Run the Flutter Mobile App

#### Option A: Android Virtual Device (AVD Emulator)
```bash
flutter run -d <emulator-id> \
  --dart-define=USE_FIREBASE_EMULATOR=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

#### Option B: Physical Android Device via USB
Reverse emulator ports to local host:
```bash
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
adb reverse tcp:5001 tcp:5001

flutter run -d <device-id> \
  --dart-define=USE_FIREBASE_EMULATOR=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

---

## Verification & Testing Gates

Run the full local gate test suite:

```bash
# 1. Code formatting check
dart format --output=none --set-exit-if-changed .

# 2. Static analysis
flutter analyze

# 3. Unit and Widget tests
flutter test

# 4. Functions compilation & tests (requires Node 20+)
cd functions
npm run build
npm test
```

---

## Honest Known Limitations

1. **Not End-to-End Encrypted (E2EE):** Agora is consent-first, transparent, and auditable, but NOT end-to-end encrypted. Group chat messages are stored in Google Cloud Firestore with granular security rules.
2. **Names Inside Message Text:** While sender UIDs and handles are pseudonymized in AI payloads, personal names or sensitive terms written directly into the body text by human authors are transmitted as written.
3. **Free-Tier Gemini Terms:** Under the Google AI free tier, data passed to the model may be logged for model improvement. Production enterprise deployments must configure Google Cloud Vertex AI with zero data retention.
4. **Direct Messaging Initiation:** In this version, any user can initiate a 1:1 direct space by providing an exact peer handle.
5. **No Automated Moderation:** Agora relies on human governance through the Space Charter and administrator roles; there is no automated content censorship filter.
6. **Demo Environment:** The demo relies on synthetic student capstone project data and local Firebase emulators.

---

## Documentation Index

- [Live Demo Runbook (Oct 15, 2026)](docs/DEMO.md)
- [Architectural Decisions Log](docs/phase5/DECISIONS.md)
- [Demo Readiness Final Report](docs/FINAL_REPORT.md)
