# Phase 3 Audit: Lens & AI Handoff Vertical Slice

**Date**: 2026-10-14  
**Branch**: `agora/demo`  
**Commit**: `487d4bf`  

---

## 1. Operating Environment & Tooling Verification

| Tool / Gate | Status | Actual Command Result / Detail |
|---|---|---|
| **Flutter SDK** | **PASS** | `Flutter 3.47.5 • channel stable`, Dart `3.13.4`, DevTools `2.60.0` (managed via Puro at `C:\Users\DELL\.puro\envs\stable\flutter\bin`) |
| **Dart Format** | **PASS** | `dart format lib test` returned exit code `0` (formatted 59 files, 0 unformatted) |
| **Flutter Analyze** | **PASS** | `flutter analyze` returned `No issues found! (ran in 19.6s)` (exit code `0`) |
| **Flutter Test Suite** | **PASS** | `flutter test` executed all 29 tests across 5 test suites (`catch_up_test.dart`, `models_test.dart`, `pulse_metrics_test.dart`, `widget_test.dart`, `rescue_golden_path_test.dart`) with `0` failures |
| **Node.js & npm** | **BLOCKED** | Neither `node` nor `npm` are installed on the host PATH. Dependent gates (`npm install`, `npm test` in `functions/`) are blocked until Node.js v20+ is present |
| **Java & Android SDK** | **BLOCKED** | Neither Java nor Android SDK are configured on PATH. `flutter build apk --debug` outputs: `[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.` |
| **Secrets Verification** | **PASS** | Neither `functions/.secret.local` nor `android/app/google-services.json` exist in git; `.gitignore` was updated to explicitly block `functions/.secret.local`, `*.secret.local`, `.env.local`, service accounts, and emulator data. Created `functions/.env.example` with placeholders only. |

---

## 2. Real Firestore Schema In Use

The schema established and validated in Firestore rules and models is:

- **`spaces/{spaceId}`**:
  - `id`: string (regex `^[A-Za-z0-9_-]{1,64}$`)
  - `kind`: `'group' | 'direct'`
  - `name`: string or null (for direct)
  - `charterVersion`: integer (starts at `1`, increments on policy expansion)
  - `aiPolicy`: `{ handoff: 'anyone' | 'admins' | 'off', maxSessionMinutes: 60 }`
  - `memberIds`: array of user UIDs
  - `memberCount`: integer
  - `createdAt`, `lastActivityAt`, `lastMessage`

- **`spaces/{spaceId}/members/{uid}`**:
  - `role`: `'owner' | 'admin' | 'member'`
  - `aiConsent`: `'allowed' | 'withheld' | 'pending'`
  - `consentCharterVersion`: integer or null
  - `consentUpdatedAt`: server timestamp
  - `lastReadAt`: timestamp (optional throttled client update)

- **`spaces/{spaceId}/messages/{messageId}`**:
  - `senderId`: author UID
  - `kind`: `'text' | 'itemCard'`
  - `text`: string (1-4000 chars)
  - `createdAt`: server timestamp
  - `replyToId`: optional string matching id regex in same Space
  - `editedAt`: timestamp (valid within 15 mins of creation)
  - `deletedAt`: timestamp (tombstone)
  - `aiSeenCount`: integer (server-written only)

- **`spaces/{spaceId}/handoffs/{uid_requestId}`**:
  - `requesterId`: UID of requester
  - `createdAt`, `completedAt`: timestamps
  - `purpose`: `'extract' | 'summarize' | 'actions'`
  - `status`: `'processing' | 'ok' | 'blocked' | 'error' | 'discarded'`
  - `dispatched`: boolean (set to true once provider payload is sent)
  - `includedMessageIds`: array of message IDs
  - `authorCount`, `proposalCount`, `payloadHash`

- **`users/{uid}/proposals/{proposalId}`**:
  - `spaceId`, `handoffId`: string
  - `type`: `'task' | 'decision' | 'question'`
  - `title`, `detail`: validated strings
  - `ownerUid`: mapped member UID or null
  - `sourceMessageIds`: array of source message IDs
  - `status`: `'pending'`
  - `expiresAt`: timestamp (+14 days)

---

## 3. Shared Authorization Core & Invariants

1. **Zero Ambient AI**: AI has no standing access to messages. Content reaches Gemini *only* via explicit human-initiated handoff callable.
2. **Binding OWN-MESSAGE Exception**:
   - `canIncludeMessage({ authorUid, requesterUid, authorEffectiveConsent })`:
     - If `authorUid === requesterUid`: returns `true` regardless of whether the requester's own consent is `'withheld'`.
     - If `authorUid !== requesterUid`: returns `true` ONLY if `authorEffectiveConsent === 'allowed'`.
   - The exception is enforced strictly on the server by comparing the verified auth UID to the server-stored `senderId`. Admins cannot bypass another member's withhold status.
3. **Effective Consent**:
   - `effectiveConsent(member, space) === 'allowed'` ONLY if `member.aiConsent === 'allowed'` AND `member.consentCharterVersion === space.charterVersion`. Pending, stale, or missing member docs evaluate to `'withheld'`.
4. **Coarse Evaluation Reasons**:
   - To prevent leaking private consent choices of other authors, excluded messages use `'excluded-author-not-allowed'` (or `'excluded-deleted'`, `'excluded-unavailable'`).

---

## 4. Existing Handoff & Proposal Code

- **Backend**:
  - `functions/src/consent.ts`: Complete with `effectiveConsent`, `canIncludeMessage`, `evaluateMessageForHandoff`, `redactContent`, `computePayloadHash`.
  - `functions/src/pipeline.ts`: Complete with `authorizeAndBuild`, `handlePreviewHandoff`, `handleRunHandoff`, idempotency locks, re-checks before dispatch, `aiSeenCount` increments, and Gemini / Fixture provider integration.
- **Flutter**:
  - `ChatScreen`: Contains Lens mode toggle, message selection (up to 50 cap), and handoff preview trigger.
  - `HandoffPreviewSheet`: Modal sheet presenting audit breakdown (included vs excluded), payload preview, and dispatch.
  - `ProposalTraySheet`: Modal sheet reviewing pending proposals.
  - `AiLedgerScreen`: Immutable audit trail for Space members.

---

## 5. Prerequisite Remediation Completed

1. Updated `.gitignore` to explicitly cover `functions/.secret.local`, `*.secret.local`, `.env.local`, `*.env.local`, service accounts, and emulator data.
2. Created `functions/.env.example` with clean placeholder variables.
3. Verified that no Gemini API keys exist in client Dart code (verified via `rescue_golden_path_test.dart`).
4. Fixed test viewport scaling for `CharterScreen` in `test/rescue_golden_path_test.dart`.
