# Agora Rescue: Current Repository State & Capability Audit

**Audit Timestamp:** 2026-10-13T22:50:00+05:30  
**Target Demo Date:** October 15, 2026 (~36 hours remaining)  
**Active Branch:** `agora/demo`  
**Git Status:** Clean tree at commit `2fc1a6b`  

---

## 1. Environment & Tooling Detection

| Tool / Dependency | Detected Version / Path | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Operating System** | Windows 11 (PowerShell 5.1) | Active | Host OS |
| **Flutter SDK** | 3.47.5 • channel stable (tools Dart 3.13.4) | **PASS** | Installed via Puro (`C:\Users\DELL\.puro\envs\stable\flutter`) |
| **Dart SDK** | 3.13.4 | **PASS** | `dart format` and `dart analyze` functional |
| **Node.js / npm** | Absent from PATH | **BLOCKED** | `node : The term 'node' is not recognized` |
| **Java JDK / javac** | Absent from PATH | **BLOCKED** | `java : The term 'java' is not recognized` |
| **Android SDK / adb** | Absent from PATH | **BLOCKED** | `[!] No Android SDK found` |
| **Firebase CLI** | Absent globally | **BLOCKED** | Depends on Node.js |
| **google-services.json** | Absent (`android/app/google-services.json`) | Normal | Client uses emulator / fallback init |
| **functions/.secret.local** | Absent | Normal | Local secrets uncommitted; fixture fallback available |

---

## 2. Gate Verification (Actual Executed Results)

1. **`flutter pub get`:** **PASS** (Resolved 17 dependencies; all packages installed).
2. **`dart format --output=none --set-exit-if-changed .`:** **PASS** (55 files checked, 0 changed).
3. **`flutter analyze`:** **PASS** (No issues found in `lib/` or `test/`).
4. **`flutter test`:** **PASS** (22 tests passed across models, widget scaling, pulse metrics, and catch-up).
5. **`functions build / test`:** **BLOCKED** (Node.js absent from host environment; TypeScript code verified statically).
6. **`flutter build apk --debug / --release`:** **BLOCKED** (Android SDK and Java absent from host environment).

---

## 3. Capability Audit Matrix (C1 - C7)

| Capability | Status | Verified Real Capabilities | Missing / Incomplete Elements to Implement |
| :--- | :--- | :--- | :--- |
| **C1: Auth, Profiles, Handles, Design System, 3-Tab Shell** | **DONE** | Firebase Auth integration, profile setup with `@handle`, default consent preference, light theme, design system tokens, 3-tab shell (`/spaces`, `/focus`, `/me`). | None. Meets all baseline design and shell requirements. |
| **C2: Spaces, Group+Direct, Members/Roles, Invites, Charter Versioning, Consent Choices** | **PARTIAL** | Space creation sheet, user spaces stream, member list, and consent badges exist in client. | Missing backend callables (`createSpace`, `startDirect`, `joinSpace`, `previewInvite`, `createInvite`, `revokeInvite`, `setMyConsent`, `updateAiPolicy`, `setMemberRole`, `removeMember`, `leaveSpace`); missing `functions/src/consent.ts` with binding OWN-MESSAGE EXCEPTION. |
| **C3: Real-Time Chat, Send/Reply/Edit/Tombstone, Triggers** | **PARTIAL** | Message stream, composer, text send, and author withhold toggle exist. | Missing: 15-minute edit window, reply spine, tombstone deletion (`text: ''`, `deletedAt`), client ID deduplication on retry, Cloud Function trigger `onMessageWritten` for `lastActivityAt`/`lastMessage`. |
| **C4: Firestore Rules Default-Deny** | **PARTIAL** | Firestore rules exist with member checks and lastReadAt update rules. | Needs hardening to spec: `memberIds` array-contains read, no client writes on spaces/members/items/handoffs, strict message key validation (`hasOnly [senderId,kind,text,createdAt,replyToId]`), edit/tombstone constraints, proposals at `users/{uid}/proposals/{id}`. |
| **C5: Handoff Pipeline, Builder, Providers, Lens UI & Hand-Off Sheet** | **PARTIAL** | `processExplicitHandoff` exists in `functions/src/index.ts`. | Missing: shared builder `authorizeAndBuild`, `previewHandoff`, `runHandoff`, full `consent.ts` with OWN-MESSAGE EXCEPTION, client Lens UI (long-press / header icon, range selection, 50 cap), hand-off preview sheet with exact payload preview. |
| **C6: Proposal Tray, Items, Board, Receipts, Footprint Marks, Ledger** | **PARTIAL** | `ProposalTraySheet` and `BoardScreen` exist in client. | Missing backend callables: `acceptProposal`, `dismissProposal`, `createManualItem`, `updateItem`, `respondToAssignment`; missing receipt context (+/- 2 surrounding messages), itemCard rendering in chat, footprint dot with sheet, AI Ledger views. |
| **C7: Demo Kit, Seed Data, Fixture Provider, Runbook** | **DONE** | `functions/scripts/seed-demo.ts`, `functions/fixtures/demo-extract.json`, `docs/DEMO.md`, `scripts/` startup scripts, `README.md`. | Verified; will ensure seed messages match updated schemas and proposal formats. |

---

## 4. Priority Roadmap (P0 - P2)

- **P0: Golden Path End-to-End**
  1. Complete `functions/src/consent.ts` (effective consent, OWN-MESSAGE EXCEPTION, handoff evaluation).
  2. Implement backend callables (`createSpace`, `startDirect`, `previewHandoff`, `runHandoff`, `acceptProposal`, `dismissProposal`, `updateItem`).
  3. Align `firestore.rules` to strict default-deny spec.
  4. Implement client Lens mode and Hand-off Sheet with exact payload preview and author exclusion.
  5. Implement item provenance receipts and itemCard chat rendering.
- **P1: Security & Logic Tests**
  - Unit tests for `consent.ts` (consent matrix, OWN-MESSAGE EXCEPTION, expansion resets).
  - Client tests for Lens selection, Hand-off preview, and Proposal Tray.
- **P2: Demo Kit & Verification**
  - Verify seed script and fixture extraction matching golden path.
  - Final report in `docs/FINAL_REPORT.md`.
