# Agora: Architectural Blueprint & Foundation Specification

## 1. Repository Inspection Summary
* **Flutter / Dart Version:** Flutter 3.47.5 (Channel stable), Dart 3.13.4.
* **Workspace Status:** Fresh initialization at `C:\Users\DELL\.gemini\antigravity-ide\scratch\agora`.
* **Platform Target:** Android-first (AGP 9.1.0, Kotlin 2.4.0, Java 17, `minSdk` configured for Firebase).
* **Dependencies Configured:**
  - State Management: `flutter_riverpod` (v3.4.3)
  - Routing: `go_router` (v18.0.2)
  - Typography: `google_fonts` (v9.0.0)
  - Backend/Auth: `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`, `firebase_messaging`, `firebase_app_check`
  - Utilities: `uuid`, `intl`

---

## 2. Product Thesis & Invariants
Agora is a **consent-first group collaboration system**, strictly governed by these core invariants:
1. **Zero Ambient AI:** AI has zero standing access to conversations. It never listens in the background.
2. **Explicit Human Handoff:** Selected messages are explicitly packaged and handed to AI by a human participant.
3. **Author Withhold Rights:** Message authors can withhold their individual messages from ever being handed over to AI, enforced at both the client and security rule levels.
4. **Proposals Only:** AI outputs are strictly non-authoritative proposals (*Tasks*, *Decisions*, or *Questions*).
5. **Human Approval Gate:** Proposals do not become system items until a human explicitly approves, edits, or dismisses them.
6. **Immutable Provenance:** Every approved item retains a cryptographically verifiable trail back to its source messages and handoff ID.
7. **Transparent Audit:** Every AI handoff is visible to all members of the Space.

---

## 3. Layered Directory Architecture
```
lib/
├── core/
│   ├── config/             # Firebase options, environment, constants
│   ├── constants/          # Collection paths, storage paths, limits
│   ├── errors/             # Failure definitions, exception handling
│   ├── theme/              # Agora design tokens: colors, typography, spacing, radius
│   └── utils/              # Formatters, validators, result types
├── features/
│   ├── auth/               # Authentication (Google, Email/Password), state, UI
│   ├── profile/            # Profile creation, unique handle reservation, Me screen
│   ├── spaces/             # Space listing, creation, settings, charter consent
│   ├── chat/               # Message feed, composer, author withhold toggle, message model
│   ├── items/              # Board items: Tasks, Decisions, Questions (provenance backed)
│   ├── pulse/              # Pulse space view (metrics, activity, status)
│   ├── focus/              # Focus view (personal queue across spaces)
│   └── handoffs/           # Handoff domain models, provenance structures
├── shared/
│   ├── design_system/      # Reusable Agora UI components (Buttons, Cards, Badges, Inputs, States)
│   ├── models/             # Shared types (Identifiable, Auditable)
│   └── widgets/            # Layout shells, responsive containers
├── router/                 # GoRouter configuration, shell routes, guards
└── app.dart                # AgoraApp widget with ProviderScope & Theme
```

---

## 4. Firestore Data Schema & Collections
```
profiles/{uid}
  - uid: String
  - handle: String (unique)
  - displayName: String
  - photoUrl: String?
  - bio: String?
  - defaultAiConsent: String ('opt_in' | 'withheld')
  - createdAt: Timestamp
  - updatedAt: Timestamp

handles/{handle}
  - uid: String
  - createdAt: Timestamp

users/{uid}
  - email: String
  - createdAt: Timestamp

devices/{deviceId}
  - uid: String
  - fcmToken: String
  - platform: String ('android' | 'ios' | 'web')
  - lastSeenAt: Timestamp

spaces/{spaceId}
  - id: String
  - name: String
  - description: String
  - charter: String
  - createdBy: String
  - createdAt: Timestamp
  - memberCount: Int
  - aiPolicy: Map (allowedProposalTypes, requireConsensus, etc.)

spaces/{spaceId}/members/{uid}
  - uid: String
  - role: String ('owner' | 'admin' | 'member')
  - joinedAt: Timestamp
  - consentState: String ('consented' | 'withheld')

spaces/{spaceId}/messages/{messageId}
  - id: String
  - spaceId: String
  - senderId: String
  - senderHandle: String
  - senderDisplayName: String
  - text: String
  - aiWithheld: Boolean (author veto against AI ingestion)
  - createdAt: Timestamp

spaces/{spaceId}/items/{itemId}
  - id: String
  - spaceId: String
  - type: String ('task' | 'decision' | 'question')
  - title: String
  - description: String
  - status: String ('open' | 'completed' | 'in_progress')
  - sourceHandoffId: String
  - sourceMessageIds: List<String> (Provenance links)
  - approvedByUid: String
  - createdAt: Timestamp

spaces/{spaceId}/handoffs/{handoffId}
  - id: String
  - spaceId: String
  - handedByUid: String
  - messageIds: List<String>
  - purpose: String
  - createdAt: Timestamp
  - auditLog: Map

proposals/{proposalId}
  - id: String
  - spaceId: String
  - handoffId: String
  - type: String ('task' | 'decision' | 'question')
  - title: String
  - payload: Map
  - status: String ('pending' | 'approved' | 'dismissed')
  - createdForUid: String
  - sourceMessageIds: List<String>
  - createdAt: Timestamp
```

---

## 5. Security Rules Specification (`firestore.rules`)
- **Handles:** Unique reservation pattern; can only be claimed if document does not already exist, and UID matches auth token.
- **Profiles:** Only owner UID can write. Public read for authenticated users.
- **Spaces & Subcollections:** Membership check `exists(/databases/$(database)/documents/spaces/$(spaceId)/members/$(request.auth.uid))` required for all reads.
- **Messages:** Write allowed only by authenticated member matching `senderId`. Updates prevented unless changing personal flags.
- **Items & Handoffs:** AI audit information and server-controlled status flags cannot be tampered with by clients.
