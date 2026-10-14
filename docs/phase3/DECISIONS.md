# Phase 3 Architecture Decisions: Lens & AI Handoff

## Decision 1: Binding OWN-MESSAGE Exception Enforcement
- **Context**: A message author may withhold their messages from general AI ingestion by other members, but chooses to initiate a handoff of a thread containing their own past statements.
- **Decision**: Server-side authorization in `canIncludeMessage` and `evaluateMessageForHandoff` evaluates `authorUid === requesterUid`. If true, the author's own message is included with reason `'included-own'`.
- **Security Boundary**: This exception is evaluated strictly on the server against the authenticated `request.auth.uid` and stored `message.senderId`. It NEVER permits a requester (even a space owner/admin) to include another author's withheld, pending, or stale-consent messages.

## Decision 2: Coarse Exclusion Reasons in Handoff Preview
- **Context**: Showing detailed reasons why another author's message was excluded might inadvertently leak whether they chose 'withheld', haven't consented to the new charter, or had their consent reset.
- **Decision**: The backend returns `'excluded-author-not-allowed'` as the standard reason for all author-consent-related exclusions in multi-member spaces, alongside `'excluded-deleted'` and `'excluded-unavailable'`.

## Decision 3: Single Shared Pipeline Builder (`authorizeAndBuild`)
- **Context**: Divergence between the preview payload and the dispatched model payload could allow prompt injection or unauthorized content leaks.
- **Decision**: `previewHandoff` and `runHandoff` call the identical builder function `authorizeAndBuild`.
- **Pre-dispatch Verification**: `runHandoff` verifies that `expectedPayloadHash === currentPayloadHash` and `expectedCharterVersion === space.charterVersion`. Immediately before invoking the provider, it performs a secondary live fetch to ensure no member revoked consent during the client roundtrip.

## Decision 4: Gemini Key Server-Side Isolation
- **Context**: API keys stored in client apps, `.env` bundles, or Flutter assets can be reverse-engineered.
- **Decision**: Google GenAI SDK is instantiated exclusively inside Firebase Cloud Functions. The client interacts solely via HTTPS `onCall` functions. Unit and widget tests verify that no API keys or `GEMINI_API_KEY` identifiers exist in `lib/`.

## Decision 5: Non-Authoritative AI Output (Private Proposals)
- **Context**: Ambient AI writing to a shared board creates phantom commitments and hallucinations.
- **Decision**: Phase 3 outputs are strictly private Proposals stored in `users/{uid}/proposals`. They do not create Board items, do not notify other users, and do not mutate shared chat state without human review.
