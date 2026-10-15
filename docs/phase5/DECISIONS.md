# Agora Phase 5: Architecture Decisions Log

## Context
Phase 5 focuses on Demo-Critical Polish and Hardening for the Oct 16, 2026 viva examination. All work is built upon verified Phases 1-4.

---

### Decision 5.1: Fixture Fallback Provider Strict Safeguards
- **Problem:** Offline viva presentations must have a dependable fallback if network or Google AI quota issues occur. However, the fixture provider must never run in production or be mistaken for Gemini integration.
- **Decision:**
  - The fixture provider requires BOTH `process.env.FUNCTIONS_EMULATOR === 'true'` AND `process.env.AI_PROVIDER === 'fixture'`.
  - If `AI_PROVIDER === 'fixture'` is requested when `FUNCTIONS_EMULATOR !== 'true'`, the function explicitly throws `failed-precondition: fixture-refused`.
  - Proposals from fixture data are stored with `provider: 'fixture'` and rendered in the client with `"Demo fixture (offline mode)"`.
  - The fixture entries match against payload tokens using `anchorContains`. Unmatched entries are skipped; matched entries pass through the EXACT same validation pipeline (`validateProposalItem`) as live Gemini responses.

---

### Decision 5.2: Strict Rule Security on Member `lastReadAt`
- **Problem:** Catch-up requires recording when a member last visited a Space. Clients must update `lastReadAt` without being able to tamper with their role, consent state, or other members' data.
- **Decision:**
  - In `firestore.rules`, updates to `spaces/{spaceId}/members/{memberUid}` are restricted to:
    ```javascript
    allow update: if isUser(memberUid) &&
                     request.resource.data.diff(resource.data).affectedKeys().hasOnly(['lastReadAt']) &&
                     request.resource.data.lastReadAt == request.time;
    ```
  - Rules tests prove that attempting to modify `role`, `consentState`, or any other member's record is rejected with permission-denied.
  - Client updates in `chat_screen.dart` are throttled (maximum once per 10 seconds), executed during unmount / navigation away, and fail silently without blocking user workflows.

---

### Decision 5.3: Catch-Up, Focus, and Pulse Determinism & Color Invariants
- **Problem:** Catch-up summaries, Focus queue, and Pulse workload indicators are frequently AI-ified in other products. Agora maintains strict honesty: these features are 100% deterministic algorithms.
- **Decision:**
  - Gold color (`AgoraColors.gold`, `goldDark`, `goldContainer`) remains STRICTLY reserved for AI-origin elements.
  - Catch-Up, Focus, and Pulse utilize Aegean blue (`AgoraColors.aegean`, `aegeanContainer`), Navy, and Terracotta (`AgoraColors.terracotta` for overdue tasks).
  - All metrics use pure calculation functions tested against edge cases (no items, all done, midnight boundary crossings).
  - Focus queries fan out across user spaces without using Firestore collection-group queries (avoiding index traps and multi-tenant data leaks).

---

### Decision 5.4: Privacy Honesty and Zero E2EE Invariant
- **Problem:** Messaging platforms frequently use sloppy marketing ("private", "secure") that users confuse with End-to-End Encryption.
- **Decision:**
  - Agora explicitly declares across its UI and documentation: *"Agora is consent-first, transparent, and auditable, but NOT end-to-end encrypted."*
  - Server-side Cloud Functions need access to consented message text to invoke Gemini. Naive E2EE claims are false and forbidden.
  - Zero Gemini API keys or prompt texts exist in the Flutter client code or Git repository.
