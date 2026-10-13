# Agora Rescue: Architectural Decisions & Invariant Ledger

## Context
- **Date:** October 13, 2026
- **Target Demo Date:** October 15, 2026 (~36 hours remaining)
- **Branch:** `agora/demo`
- **Scope:** Complete, verify, and harden ONLY missing capabilities in strict priority order (P0 > P1 > P2).

---

## Decision 1: Binding Own-Message Exception
* **Invariant:** A requester executing a handoff may include their **OWN** messages even if they personally withheld consent for other members' handoffs.
* **Security Boundary:** This exception applies **ONLY** to the requester's own messages (`authorUid === requesterUid`). It **NEVER** allows anyone (including administrators) to include another author's withheld, pending, or stale-consent messages.
* **Implementation:** Encapsulated inside `functions/src/consent.ts` in `canIncludeMessage`:
  ```typescript
  export function canIncludeMessage(params: {
    authorUid: string;
    requesterUid: string;
    authorEffectiveConsent: 'allowed' | 'withheld' | 'pending';
  }): boolean {
    if (params.authorUid === params.requesterUid) {
      return true; // OWN-MESSAGE EXCEPTION
    }
    return params.authorEffectiveConsent === 'allowed';
  }
  ```

---

## Decision 2: Backend Architecture & Shared Consent Module
* Implement `functions/src/consent.ts` as the single source of truth for:
  - `effectiveConsent(member, space)`: `'allowed'` only if `aiConsent === 'allowed'` AND `consentCharterVersion === space.charterVersion`; all other states evaluate to `'withheld'`.
  - `evaluateMessageForHandoff`: produces exact reason codes (`included-own`, `included-consented`, `excluded-withheld`, `excluded-deleted`, `excluded-invalid`).
  - `policyPermitsHandoff(space, role)`: enforces `'anyone'`, `'admins'`, or `'off'`.
  - Charter expansion resets: when AI policy expands (e.g. `off` -> `admins` -> `anyone`), `charterVersion` is bumped and all `'allowed'` members are reset to `'pending'`. Narrowing does not reset consent.

---

## Decision 3: Pipeline & Handoff Integrity
* `authorizeAndBuild`: Shared builder function used identically by `previewHandoff` and `runHandoff`.
* Prevents discrepancies between what the user previews and what is transmitted to AI.
* Computes `payloadHash = sha256(canonicalJson)`.
* Re-evaluates consent and space state immediately prior to provider dispatch; aborts with `consent-changed` if any author retracted consent between preview and run.

---

## Decision 4: Client Lens Mode & Exact Payload Preview
* In Chat, user can activate Lens via gold ✦ header icon or message long-press.
* Range selection + multi-select up to 50 messages.
* Hand-off preview sheet shows:
  - Exactly what will be sent (server payload with redactions).
  - Explicit list of excluded messages with reasons (withheld author, deleted).
  - Confirmation that names, emails, other messages, and other Spaces are never sent.
  - Strict prohibition against automatic persistence: outputs are private proposals only.

---

## Decision 5: Non-Authoritative Proposal Store & Provenance
* Model outputs are stored in `users/{uid}/proposals/{id}` with `status: 'pending'`.
* Only explicit human execution of `acceptProposal` creates items in `spaces/{spaceId}/items`.
* `acceptProposal` re-validates source messages to ensure deleted messages are not fabricated as evidence.
* Receipts display the source message plus up to 2 surrounding messages of contextual history.
