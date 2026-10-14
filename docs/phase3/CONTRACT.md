# Phase 3 Contract: Handoff Pipeline, Payload & Proposal Schemas

## 1. Handoff Input Contract

### Callable: `previewHandoff`
- **Request Parameters**:
  - `spaceId`: `string` (regex `^[A-Za-z0-9_-]{1,64}$`)
  - `messageIds`: `string[]` (1 to 50 unique IDs, matching regex)
  - `purpose`: `'extract' | 'summarize' | 'actions'` (default: `'extract'`)
  - `customInstruction`: optional `string` (max 200 chars, stripped of control characters)
- **Response**:
  - `charterVersion`: `number`
  - `policy`: `'anyone' | 'admins' | 'off'`
  - `items`: Array of:
    - `messageId`: `string`
    - `status`: `'included' | 'excluded'`
    - `reason`: `'included-own' | 'included-consented' | 'excluded-author-not-allowed' | 'excluded-deleted' | 'excluded-unavailable'`
    - `authorLabel`: `string` (e.g. `'Member A'`, `'You'`)
  - `counts`:
    - `totalRequested`: `number`
    - `included`: `number`
    - `excludedAuthorNotAllowed`: `number`
    - `excludedDeleted`: `number`
    - `excludedUnavailable`: `number`
  - `payload`: Array of pseudonymized messages (see Section 2)
  - `payloadHash`: Canonical SHA-256 string

---

### Callable: `runHandoff`
- **Request Parameters**:
  - `spaceId`: `string`
  - `messageIds`: `string[]` (1-50 IDs)
  - `purpose`: `'extract' | 'summarize' | 'actions'`
  - `customInstruction`: optional `string` (max 200 chars)
  - `requestId`: `string` (client-generated UUID for idempotency)
  - `expectedPayloadHash`: `string` (hash returned from `previewHandoff`)
  - `expectedCharterVersion`: `number` (charterVersion from `previewHandoff`)
- **Response**:
  - `status`: `'ok'`
  - `handoffId`: `string` (`${requesterUid}_${requestId}`)
  - `proposalCount`: `number`
  - `cached`: optional `boolean`

---

## 2. Pseudonymized Handoff Payload

The payload dispatched to Gemini contains strictly redacted, tokenized entries:
```json
[
  {
    "token": "m1",
    "authorLabel": "Member A",
    "timestampIso": "2026-10-12T14:30:00.000Z",
    "text": "Can someone draft the [link] by Friday? My number is [phone]."
  }
]
```

### Absolute Redaction Rules:
- **Email addresses**: replaced with `[email]`
- **Phone numbers**: replaced with `[phone]`
- **9+ digit runs**: replaced with `[number]`
- **HTTP/HTTPS URLs**: replaced with `[link]`
- **Identity isolation**: UIDs, real display names, handles, Space name, and other messages are NEVER passed to the AI provider.

---

## 3. Proposal Schema (`users/{uid}/proposals/{id}`)

Outputs returned by Gemini are parsed into private Proposals for human review:
- `id`: string
- `spaceId`: string
- `handoffId`: string
- `type`: `'task' | 'decision' | 'question'`
- `title`: string (1-120 chars)
- `detail`: string (<=500 chars)
- `ownerUid`: mapped member UID or null
- `volunteered`: boolean
- `dueDate`: ISO date string or null
- `dueNeedsConfirm`: boolean
- `sourceMessageIds`: string[] (all referencing valid message IDs from this handoff)
- `confidence`: number (0.0 to 1.0)
- `status`: `'pending'`
- `provider`: `'gemini' | 'fixture'`
- `createdAt`: server timestamp
- `expiresAt`: timestamp (+14 days)

---

## 4. Error Code Taxonomy

| Code | HTTP / HttpsError | Description |
|---|---|---|
| `policy-off` | `failed-precondition` | AI handoffs are disabled in Space Charter |
| `admins-only` | `permission-denied` | Space policy restricts handoffs to admins |
| `not-a-member` | `permission-denied` | Caller is not a current member of the Space |
| `charter-changed` | `failed-precondition` | Charter version updated between preview and dispatch |
| `payload-changed` | `failed-precondition` | Payload hash mismatch between preview and dispatch |
| `consent-changed` | `failed-precondition` | An author revoked consent immediately before dispatch |
| `nothing-to-send` | `failed-precondition` | All selected messages were excluded |
| `rate-limited` | `resource-exhausted` | Hourly or daily quota exceeded |
| `in-progress` | `already-exists` | Concurrent handoff for this requestId is processing |
| `ai-not-configured` | `failed-precondition` | Server-side Gemini API key is missing |
| `ai-invalid-output` | `internal` | Gemini output failed schema validation after retry |
