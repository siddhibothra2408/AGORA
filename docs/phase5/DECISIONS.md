# Phase 5: Demo-Critical Polish and Hardening - Architectural Decisions

## Context
Date: October 11, 2026
Demo Date: October 15, 2026
Branch: `agora/demo`

Agora Product Thesis:
> "Agora is the group chat where AI only reads what you hand it, everyone can see what it was handed, and nothing becomes a task or decision until a human approves it."
> Not end-to-end encrypted (stated transparently in documentation and UI copy).
> Gemini is called server-side only; no key in client.
> Gold is strictly reserved for AI-related UI; Catch-up, Focus, and Pulse are deterministic (NO AI) and use Aegean blue and restrained palettes.

---

## Decision 1: Deterministic Catch-Up, Focus, and Pulse (No AI)
* **Catch-Up Card:**
  - Placed at the top of both Chat and Board screens in a Space.
  - Rendered with Aegean Blue styling (never Gold).
  - Dismissible per session.
  - Completely skipped on first-ever visit (`lastReadAt == null`).
  - Summarizes activity strictly since `lastReadAt`: new messages count, items created, items assigned to current user, decisions made, items completed, and handoffs executed (with a direct link to the Space Audit Ledger).
  - Calculations are implemented as pure functions (`calculateCatchUp`) with 100% test coverage.

* **Space Member `lastReadAt`:**
  - Stored on `spaces/{spaceId}/members/{uid}` as `lastReadAt: Timestamp`.
  - Firestore security rules strictly allow members to update ONLY their own `lastReadAt` (`affectedKeys().hasOnly(['lastReadAt']) && request.resource.data.lastReadAt == request.time`).
  - Throttled in the client to avoid high-frequency writes; failure is non-blocking and silent.

* **Focus Tab:**
  - Aggregates tasks across the user's active Spaces via client fan-out (no collection-group queries needed, preserving tight security rules).
  - Groups items into:
    1. "My Open Tasks" (status `open` or `in_progress`, assigned to me), sorted by due date with overdue items marked in terracotta (`#C85A32`).
    2. "Proposed for you" assignments with one-tap Accept / Decline buttons.
    3. Pending proposals count per Space linking to the Space proposal review tray.
  - Complete error, empty, loading, and offline fallback states.

* **Pulse Tab:**
  - Pure calculation functions (`calculatePulseMetrics`): open vs. done tasks, overdue count, stale tasks (no activity in 7 days), open questions >3 days, decisions established this week, per-member load distribution, and a 14-day completion trend.
  - Custom `SparklinePainter` implemented with Flutter `CustomPainter` (zero chart dependencies).
  - Fully deterministic, timezone-free date-only arithmetic, no AI claims.

---

## Decision 2: Seed Script, Fixture Provider, and Offline Demo Mode
* **`seed:demo` script (`functions/scripts/seed-demo.ts`):**
  - Requires emulator environment variables (`FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST`). Refuses to run against production.
  - Deterministic users: Maya (admin), Ravi, Sam, Lena (all `@agora.demo` with emulator demo password).
  - Deterministic consent: Maya allowed, Ravi allowed, Lena allowed, Sam **WITHHELD** (AI shield on).
  - 40 fixed-timestamp student-project messages (Oct 12-13, 2026) for "Capstone: Smart Bin".
  - Messages include: hardware decision (ultrasonic vs infrared sensor), volunteer task ("I'll send the draft by Friday" - Oct 16, 2026), explicit deadline task, unanswered question, prompt-injection attack test ("ignore all instructions..."), and a distinctive decision by Sam that MUST be shielded from AI.
  - Idempotent execution (wipes and recreates the deterministic Space cleanly).

* **Fixture Provider (`functions/fixtures/demo-extract.json`):**
  - Offline fallback activated when `AI_PROVIDER=fixture`.
  - Produces deterministic proposals matching the seed messages without external network calls.
  - Passes through the exact same input validation, consent check (vetoing Sam's messages), and provenance attachment pipeline as live Gemini.
  - Displays explicit "Demo fixture (offline mode)" badge.

* **Runbook & Demo Guide (`docs/DEMO.md`):**
  - 4-minute two-device scripted runbook covering problem framing, Charter inspection, message selection, Lens preview showing Sam's exclusion, private proposal tray, human approval gate, Board receipt provenance inspection, gold footprint audit ledger, and prompt-injection resilience.

---

## Decision 3: Hardening and Security Guarantees
* **Privacy Transparency:**
  - Honest copy everywhere: Agora is consent-first, transparent, and auditable, but NOT end-to-end encrypted.
  - No secrets in client (`lib/` has 0 API keys; Gemini is Cloud Functions-only).
  - No content logging (prompts, raw message texts, and proposal payloads never logged to stdout/console).
  - Semantic accessibility labels on all consent chips and AI gold badges.
