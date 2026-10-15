# Phase 4 Architecture Decisions: Ratification, Board & Provenance

## Decision 1: Strict Transactional Serialization for Proposal Acceptance
- **Context**: Double-tapping 'Accept' or concurrent acceptance requests must yield exactly one Board item and must not increment audit counters multiple times.
- **Decision**: `acceptProposal` uses `db.runTransaction` (reads before writes).
- **Behavior**: If the proposal is already marked `status === 'accepted'`, the transaction immediately returns `{ success: true, itemId: prop.acceptedItemId, alreadyAccepted: true }` without writing any new item, itemCard, or incrementing `handoff.acceptedCount`.

## Decision 2: Real-Time Provenance Integrity & No Fabricated History
- **Context**: Source messages may be edited or tombstoned/deleted after an AI handoff has occurred.
- **Decision**: When a proposal is accepted, the server fetches all current source messages:
  - Any deleted or missing messages are dropped from `sourceRefs`.
  - If a message was edited after the handoff timestamp (`editedAt > handoff.createdAt`), it is flagged with `editedSinceHandoff: true`.
  - If all source messages have been deleted, the transaction is rejected with `failed-precondition: sources-unavailable`. Agora never fabricates provenance for phantom messages.

## Decision 3: Structural Guarantee: AI Pipeline Never Writes Items
- **Context**: The product thesis strictly states: *"nothing becomes a task or decision until a human approves it."*
- **Decision**: Neither `runHandoff`, `previewHandoff`, nor any AI model/fixture provider has standing permission or code paths to write to `spaces/{spaceId}/items` or generate `itemCard` messages.
- **Verification**: Static code scan and automated tests enforce that the handoff pipeline never writes to the `items` collection.

## Decision 4: Gold Exclusivity Invariant
- **Context**: Visual clarity on what is AI-proposed versus human-created or approved.
- **Decision**: Gold (`#C69214` / `AgoraColors.gold`) is reserved exclusively for AI elements:
  - Private Proposal cards in the Proposal Tray.
  - "AI-assisted · approved by <name>" chips on Board items with `origin === 'ai'`.
  - Footprint dots on chat messages where `aiSeenCount > 0`.
  - AI Ledger navigation and audit details.
  - Manual items, ordinary status chips, and non-AI Board elements use Aegean blue (`#1A5276`), navy, or neutral surface tokens.

## Decision 5: Non-Optimistic UI for Ratification
- **Context**: Proposal ratification produces permanent shared Space records (Board item and chat card).
- **Decision**: The Proposal Tray uses real progress indicators and handles errors directly from the server. Proposals remain in the tray with clear status feedback until the server confirms acceptance or dismissal.
