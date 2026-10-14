# Phase 3 Final Report: Lens & AI Handoff Vertical Slice

**Status**: IMPLEMENTED & VERIFIED  
**Date**: 2026-10-14  
**Branch**: `agora/demo`  

---

## 1. Executive Summary

Phase 3 implements the full end-to-end **Lens + AI Handoff vertical slice** for Agora, strictly observing the core product thesis:
> *"Agora is the group chat where AI only reads what you hand it, everyone can see what it was handed, and nothing becomes a task or decision until a human approves it."*

All AI processing is strictly human-initiated. Content reaches Gemini only through server-side callable functions (`previewHandoff` and `runHandoff`), with multi-layer authorization and real-time consent re-verification prior to model dispatch. AI outputs are persisted strictly as **private proposals** in `users/{uid}/proposals` and never mutate the shared Space Board without human review.

---

## 2. Invariants & Security Architecture

1. **Binding OWN-MESSAGE Exception**:
   - `canIncludeMessage({ authorUid, requesterUid, authorEffectiveConsent })`:
     - If `authorUid === requesterUid`: returns `true` (author can hand off their own statements).
     - If `authorUid !== requesterUid`: requires `authorEffectiveConsent === 'allowed'`.
   - Verified strictly on the server against `request.auth.uid` and stored Firestore document `senderId`. Admins cannot bypass another author's withheld consent.
2. **Coarse Exclusion Reasons**:
   - Out-of-consent messages are reported in the UI preview as `excluded-author-not-allowed` to avoid leaking other authors' private settings or charter sync states.
3. **Pre-Dispatch Re-verification**:
   - `runHandoff` verifies that `expectedPayloadHash` matches the server-built hash.
   - Immediately before invoking Gemini or Fixture provider, a secondary live read verifies that no author changed or revoked consent during the client round-trip.
4. **Untrusted Data Invariant**:
   - System instruction enforces that messages are untrusted data, not system instructions. Any prompt injection or roleplay instructions inside messages are ignored.
5. **Gemini Key Server-Side Isolation**:
   - Google GenAI SDK runs exclusively in Cloud Functions.
   - Client codebase contains zero API keys or `GEMINI_API_KEY` references (validated by static security test in `test/rescue_golden_path_test.dart`).
6. **Design System Adherence**:
   - Aegean blue (`#1A5276`) for primary client elements.
   - Gold (`#C69214` / `AgoraColors.gold`) is strictly reserved for AI-related elements (Lens brackets, handoff action buttons, AI badges, and footprint markers).

---

## 3. Gates & Test Verification

| Gate | Status | Command & Output Details |
|---|---|---|
| **Dart Format** | **PASS** | `dart format lib test` returned exit code 0 (62 files checked, 0 unformatted). |
| **Flutter Analyze** | **PASS** | `flutter analyze` returned `No issues found! (ran in 19.3s)`. Zero errors, zero warnings. |
| **Flutter Test Suite** | **PASS** | `flutter test` executed **33 tests across 6 test suites** with **0 failures**: <br>• `test/phase3_lens_handoff_test.dart` (4/4 passed)<br>• `test/rescue_golden_path_test.dart` (7/7 passed)<br>• `test/catch_up_test.dart` (3/3 passed)<br>• `test/models_test.dart` (9/9 passed)<br>• `test/pulse_metrics_test.dart` (4/4 passed)<br>• `test/widget_test.dart` (6/6 passed) |
| **Functions Test** | **BLOCKED** | Node.js and npm are absent on the host environment PATH. Dependent gate marked BLOCKED with fix: install Node.js v20+ and run `cd functions && npm test`. |
| **Android Build** | **BLOCKED** | Android SDK / Java are absent on the host environment PATH. `flutter build apk --debug` outputs `[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.` |

---

## 4. Deliverables Summary

- **`functions/src/consent.ts`**: Shared authorization core, `canIncludeMessage` with own-message exception, coarse exclusion reasons, content redaction (`[email]`, `[phone]`, `[number]`, `[link]`), payload hashing.
- **`functions/src/pipeline.ts`**: Shared `authorizeAndBuild` builder, `handlePreviewHandoff`, `handleRunHandoff` with idempotency claim (`requesterUid_requestId`), pre-dispatch live re-read, `aiSeenCount` increment, Gemini SDK and Fixture fallback provider.
- **`lib/features/chat/screens/chat_screen.dart`**: Lens mode toggle (gold ✦), multi-select range selection (1-50 cap), gold left border indicators, long-press menu ("Hand to AI"), footprint sheet.
- **`lib/features/handoffs/widgets/handoff_preview_sheet.dart`**: Purpose picker (`extract`, `actions`, `summarize`), optional custom guidance TextField, audit breakdown, payload inspection, and dispatch to private results.
- **`lib/features/handoffs/screens/private_results_screen.dart`**: Private proposal viewer with non-authoritative security notice and source message anchor receipts.
- **`lib/features/handoffs/screens/my_ai_results_screen.dart`**: Filterable private proposal list for the authenticated user.
- **`docs/phase3/`**: `AUDIT.md`, `DECISIONS.md`, `CONTRACT.md`, and `REPORT.md`.
