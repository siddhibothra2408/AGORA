# Phase 4 Audit: Prerequisite & Real System Architecture

**Date**: 2026-10-15  
**Local Branch**: `agora/phase-4`  
**Base Tag**: `submission-oct15` (created on commit `ed4edc3`)  
**Product Invariant**: "Agora is the group chat where AI only reads what you hand it, everyone can see what it was handed, and nothing becomes a task or decision until a human approves it."

---

## 1. Git State & Branching

- **Current Branch**: `agora/phase-4` (branched from `agora/demo` at commit `ed4edc3`).
- **Tag**: `submission-oct15` established on commit `ed4edc3`.
- **Working Tree**: Clean.
- **Recent Git Log**:
  - `ed4edc3` `test(phase3): add MyAiResultsScreen filtering widget test and verify 36 passing tests`
  - `3e10c16` `feat(phase3): refine coarse reasons, dual-target proposal persistence, and audit validation`
  - `ec19be5` `feat(phase3): implement Lens selection, handoff pipeline with own-message exception, and private results screen`
  - `487d4bf` `chore(checkpoint): safety commit before Phase 3 audit and implementation`
  - `115dd69` `feat(rescue): implement backend consent module, spaces, pipeline, items, and hardened firestore rules`

---

## 2. Real Schema & Data Locations

### A. Proposals
- **Location**: Primary private storage is `users/{uid}/proposals/{proposalId}` with dual-write to root `proposals/{proposalId}` for query compatibility.
- **Fields**:
  - `id`: `string` (`prop_${handoffId}_${index}`)
  - `spaceId`: `string`
  - `handoffId`: `string` (`${requesterUid}_${requestId}`)
  - `type`: `'task' | 'decision' | 'question'`
  - `title`: `string` (1-120 chars)
  - `detail`: `string` (<=500 chars)
  - `ownerUid`: `string | null`
  - `createdForUid`: `string` (the requester)
  - `volunteered`: `boolean`
  - `dueDate`: ISO-8601 string or null
  - `dueNeedsConfirm`: `boolean`
  - `sourceMessageIds`: `string[]` (tokens mapped back to real Firestore message IDs)
  - `confidence`: `number` (0.0 to 1.0)
  - `status`: `'pending' | 'accepted' | 'dismissed'`
  - `provider`: `'gemini' | 'fixture'`
  - `createdAt`: Firestore server timestamp
  - `expiresAt`: Firestore timestamp (+14 days)

### B. Handoff Audit Documents
- **Space Level**: `spaces/{spaceId}/handoffs/{handoffId}`
  - `requesterId`: `string`
  - `createdAt`: server timestamp
  - `completedAt`: server timestamp
  - `purpose`: `'extract' | 'actions' | 'summarize'`
  - `mode`: `'oneTime'`
  - `status`: `'ok' | 'blocked' | 'error' | 'processing'`
  - `dispatched`: `boolean`
  - `charterVersion`: `number`
  - `policy`: `'anyone' | 'admins' | 'off'`
  - `includedMessageIds`: `string[]`
  - `excluded`: `{ authorNotAllowed: number, deleted: number, unavailable: number }`
  - `authorCount`: `number`
  - `proposalCount`: `number`
  - `acceptedCount`: `number` (server-incremented on proposal acceptance)
  - `dismissedCount`: `number` (server-incremented on proposal dismissal)
  - `payloadHash`: `string` (SHA-256)
  - `provider`: `'gemini' | 'fixture'`
  - `model`: `string`
- **Global Immutable Audit**: `aiOutputs/{handoffId}`
  - Captures `handedByUid`, `provider`, `model`, `proposalCount`, `includedCount`, and `createdAt`.

### C. Footprint Field
- **Message Document**: `spaces/{spaceId}/messages/{messageId}`
  - Field: `aiSeenCount` (integer counter).
  - Incremented server-side atomically via `FieldValue.increment(1)` during `runHandoff` for every included message.

### D. Board Items
- **Location**: `spaces/{spaceId}/items/{itemId}`
- **Permissions**: Read allowed for space members; write disallowed for clients (written strictly by server callables).
- **Fields**:
  - `id`: `string`
  - `spaceId`: `string`
  - `type`: `'task' | 'decision' | 'question'`
  - `title`: `string` (1-120 chars)
  - `detail`: `string` (<=500 chars)
  - `status`:
    - task: `'open' | 'done' | 'dropped'`
    - decision: `'active' | 'superseded'`
    - question: `'open' | 'answered' | 'dismissed'`
  - `ownerUid`: `string | null`
  - `ownerState`: `'unassigned' | 'proposed' | 'accepted' | 'declined'`
  - `dueDate`: `'YYYY-MM-DD'` or null
  - `volunteered`: `boolean`
  - `origin`: `'ai' | 'manual'`
  - `handoffId`: `string | null`
  - `sourceRefs`: `Array<{ messageId: string, editedSinceHandoff: boolean }>`
  - `approvedBy`: `string | null` (UID of approver for AI origin)
  - `approvedAt`: server timestamp
  - `editedByHuman`: `boolean`
  - `createdBy`: `string` (UID)
  - `createdAt`: server timestamp
  - `updatedAt`: server timestamp
  - `updatedBy`: `string` (UID)
  - `resolvedAt`: server timestamp or null

### E. Chat Item Cards
- **Message Document**: `spaces/{spaceId}/messages/{item_itemId}`
- **Kind**: `'itemCard'` (server-written; client rules forbid creating any kind other than `'text'`).
- **Fields**: `id`, `spaceId`, `senderId` (approver UID), `kind: 'itemCard'`, `text: 'Added <type>: <title>'`, `itemRef: { itemId, type, title }`, `createdAt`.

---

## 3. Prerequisite Environment Check

| Tool / Runtime | Version / Detection | Status | Notes |
|---|---|---|---|
| **Flutter** | `3.47.5` • channel stable • Tools • Dart 3.13.4 | **READY** | Managed by Puro at `C:\Users\DELL\.puro\envs\stable\flutter\bin\flutter.bat` |
| **Dart** | `3.13.4` (stable) | **READY** | Tools build and test cleanly |
| **Node.js** | Not found in PATH | **BLOCKED** | Required for local Cloud Functions unit tests. Fix: Install Node.js v20+ |
| **npm / npx** | Not found in PATH | **BLOCKED** | Required for `firebase-tools` emulator execution |
| **Java / JDK** | Not found in PATH | **BLOCKED** | Required for Firebase Java emulators and Android APK builds |
| **Android SDK / adb** | Not found in PATH (`ANDROID_HOME` unset) | **BLOCKED** | `flutter build apk --debug` outputs `[!] No Android SDK found` |

---

## 4. Verification Gate Results (Checkpoint 0)

1. `flutter pub get`: **PASS** (Resolved dependencies cleanly).
2. `dart format --output=none --set-exit-if-changed lib test`: **PASS** (0 unformatted files out of 63).
3. `flutter analyze`: **PASS** (`No issues found! (ran in 12.0s)`).
4. `flutter test`: **PASS** (**36 tests passed across 6 test suites**, 0 failures).
5. `flutter build apk --debug`: **BLOCKED** (`[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.`).

---

## 5. Architectural Findings & Gap Analysis for Phase 4

1. **Transaction Isolation in `acceptProposal`**:
   - `functions/src/items.ts` currently uses a `batch` for `acceptProposal`. Checkpoint 2 requires a Firestore Transaction (`db.runTransaction`) to guarantee strict serialization for idempotent concurrent double-accept calls.
   - Validation for `ownerUid` must ensure the user is an active Space member (`spaces/{spaceId}/members/{ownerUid}`).
   - Verify `expiresAt`: reject expired proposals.
   - Load handoff and verify `handoff.requesterId === caller`.
2. **Interactive Proposal Tray**:
   - Enhance [proposal_tray_sheet.dart](file:///C:/Users/DELL/.gemini/antigravity-ide/scratch/agora/lib/features/handoffs/widgets/proposal_tray_sheet.dart) with live source message quote fetching, "Source message deleted" indicators, and "Edited since handoff" badges.
3. **Board Real-Time Views**:
   - Verify [board_screen.dart](file:///C:/Users/DELL/.gemini/antigravity-ide/scratch/agora/lib/features/items/screens/board_screen.dart) realtime listeners for Tasks, Decisions, and Questions, ensuring gold is reserved strictly for AI-origin items.
4. **Item Detail Receipts**:
   - Enhance [item_receipts_sheet.dart](file:///C:/Users/DELL/.gemini/antigravity-ide/scratch/agora/lib/features/items/widgets/item_receipts_sheet.dart) to show context messages (up to 2 messages before and after) fetched live without fabricating deleted/edited text.
5. **AI Ledger & Footprints**:
   - Verify [ai_ledger_screen.dart](file:///C:/Users/DELL/.gemini/antigravity-ide/scratch/agora/lib/features/handoffs/screens/ai_ledger_screen.dart) and chat footprint badges for messages where `aiSeenCount > 0`.
