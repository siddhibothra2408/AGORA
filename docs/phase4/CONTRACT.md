# Phase 4 Contract: Proposal Ratification, Board & Provenance

## 1. Firestore Data Contracts

### A. Board Items (`spaces/{spaceId}/items/{itemId}`)
*Server-written only; read allowed for Space members.*

```typescript
interface SpaceItem {
  id: string; // ^[A-Za-z0-9_-]{1,64}$
  spaceId: string;
  type: 'task' | 'decision' | 'question';
  title: string; // 1-120 characters, trimmed, stripped of HTML
  detail: string; // 0-500 characters
  status:
    | 'open' | 'done' | 'dropped' // for task
    | 'active' | 'superseded'      // for decision
    | 'open' | 'answered' | 'dismissed'; // for question
  ownerUid: string | null;
  ownerState: 'unassigned' | 'proposed' | 'accepted' | 'declined';
  dueDate: string | null; // ISO YYYY-MM-DD or null
  volunteered: boolean;
  origin: 'ai' | 'manual';
  handoffId: string | null;
  sourceRefs: Array<{
    messageId: string;
    editedSinceHandoff: boolean;
  }>;
  approvedBy: string | null; // UID of approver (for origin === 'ai')
  approvedAt: Timestamp;
  editedByHuman: boolean;
  createdBy: string; // UID of creator/approver
  createdAt: Timestamp;
  updatedAt: Timestamp;
  updatedBy: string; // UID of modifier
  resolvedAt?: Timestamp | null;
}
```

### B. Chat Item Cards (`spaces/{spaceId}/messages/{item_itemId}`)
*Server-written only; read allowed for Space members. Clients cannot write kind `'itemCard'`.*

```typescript
interface ItemCardMessage {
  id: string; // "item_" + itemId
  spaceId: string;
  senderId: string; // Approver/Creator UID
  kind: 'itemCard';
  text: string; // "Added <type>: <title>" (max 80 chars)
  itemRef: {
    itemId: string;
    type: 'task' | 'decision' | 'question';
    title: string;
  };
  createdAt: Timestamp;
}
```

### C. Proposals (`users/{uid}/proposals/{proposalId}`)
*Owner read-only; mutations executed strictly via callables.*

```typescript
interface ProposalDoc {
  id: string;
  spaceId: string;
  handoffId: string;
  type: 'task' | 'decision' | 'question';
  title: string;
  detail: string;
  ownerUid: string | null;
  createdForUid: string;
  volunteered: boolean;
  dueDate: string | null;
  dueNeedsConfirm: boolean;
  sourceMessageIds: string[];
  confidence: number;
  status: 'pending' | 'accepted' | 'dismissed';
  acceptedItemId?: string | null;
  provider: 'gemini' | 'fixture';
  createdAt: Timestamp;
  expiresAt: Timestamp; // 14-day retention window
  updatedAt?: Timestamp;
}
```

### D. Handoff Audit Documents (`spaces/{spaceId}/handoffs/{handoffId}`)
*Members read-only; server-written by handoff and acceptance callables.*

```typescript
interface HandoffAuditDoc {
  handoffId: string;
  spaceId: string;
  requesterId: string;
  purpose: 'extract' | 'actions' | 'summarize';
  mode: 'oneTime';
  status: 'ok' | 'blocked' | 'error' | 'processing';
  dispatched: boolean;
  charterVersion: number;
  policy: 'anyone' | 'admins' | 'off';
  includedMessageIds: string[];
  excluded: {
    authorNotAllowed: number;
    deleted: number;
    unavailable: number;
  };
  authorCount: number;
  proposalCount: number;
  acceptedCount: number; // Incremented on ratification
  dismissedCount: number; // Incremented on dismissal
  payloadHash: string;
  provider: string;
  model: string;
  createdAt: Timestamp;
  completedAt: Timestamp;
}
```

---

## 2. Callable Endpoint Contracts

### 1. `acceptProposal`
Accepts a private AI proposal, checks source message freshness, and creates a ratified Space item and item card in a single atomic transaction.

- **Request**:
  ```typescript
  {
    proposalId: string;
    edits?: {
      type?: 'task' | 'decision' | 'question';
      title?: string; // 1-120 chars
      detail?: string; // 0-500 chars
      ownerUid?: string | null;
      dueDate?: string | null;
    };
  }
  ```
- **Response**:
  ```typescript
  {
    success: true;
    itemId: string;
    itemCardMsgId: string;
    alreadyAccepted?: boolean;
  }
  ```
- **Error Codes**:
  - `unauthenticated`: Missing user auth
  - `not-found`: Proposal not found
  - `permission-denied`: Caller not space member, or caller does not own the handoff
  - `failed-precondition`: Proposal not pending, proposal expired, or `sources-unavailable` (all source messages deleted)
  - `invalid-argument`: Edits exceed field lengths or invalid date format

### 2. `dismissProposal`
Dismisses a private AI proposal.

- **Request**: `{ proposalId: string }`
- **Response**: `{ success: true, alreadyDismissed?: boolean }`

### 3. `createManualItem`
Creates an item directly without AI (the AI-free fallback path).

- **Request**:
  ```typescript
  {
    spaceId: string;
    type: 'task' | 'decision' | 'question';
    title: string;
    detail?: string;
    ownerUid?: string | null;
    dueDate?: string | null;
    sourceMessageIds?: string[];
  }
  ```
- **Response**: `{ success: true, itemId: string }`

### 4. `updateItem`
Transitions item lifecycle status.

- **Request**:
  ```typescript
  {
    spaceId: string;
    itemId: string;
    action:
      | 'complete' | 'reopen' | 'drop'     // task
      | 'supersede' | 'reactivate'         // decision
      | 'answer' | 'reopen' | 'dismiss';   // question
  }
  ```
- **Response**: `{ success: true, newStatus: string }`

### 5. `respondToAssignment`
Allows designated owner to accept or decline proposed ownership.

- **Request**: `{ spaceId: string; itemId: string; accept: boolean }`
- **Response**: `{ success: true, ownerState: 'accepted' | 'declined' }`

---

## 3. Required Firestore Composite Indexes

1. `spaces/{spaceId}/items`: `type` (ASC), `createdAt` (DESC)
2. `spaces/{spaceId}/items`: `handoffId` (ASC), `createdAt` (DESC)
3. `spaces/{spaceId}/handoffs`: `createdAt` (DESC)
4. `spaces/{spaceId}/handoffs`: `includedMessageIds` (ARRAY-CONTAINS), `createdAt` (DESC)
5. `proposals`: `spaceId` (ASC), `status` (ASC), `createdAt` (DESC)
