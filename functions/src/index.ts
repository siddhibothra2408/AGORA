/**
 * Agora Cloud Functions v2 (TypeScript)
 *
 * Core Architecture Invariants:
 * 1. AI is ONLY invoked through explicit callable functions triggered by human handoff.
 * 2. NO background or ambient triggers on chat messages.
 * 3. Gemini API keys are strictly server-side environment secrets.
 * 4. Outputs are strictly non-authoritative Proposals (tasks, decisions, questions).
 * 5. Every handoff produces an immutable audit record in aiOutputs and space handoffs.
 * 6. Withheld messages are strictly excluded prior to model dispatch.
 * 7. BINDING OWN-MESSAGE EXCEPTION: A requester may include their OWN messages even if withheld.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

import {
  handleCreateSpace,
  handleStartDirect,
  handleCreateInvite,
  handlePreviewInvite,
  handleJoinSpace,
  handleSetMyConsent,
  handleUpdateAiPolicy,
} from "./spaces";

import {
  handlePreviewHandoff,
  handleRunHandoff,
} from "./pipeline";

import {
  handleAcceptProposal,
  handleDismissProposal,
  handleCreateManualItem,
  handleUpdateItem,
  handleRespondToAssignment,
} from "./items";

function requireAuth(request: any): string {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  return request.auth.uid;
}

// ============================================================================
// Spaces & Membership Callables (SPEC C2)
// ============================================================================

export const createSpace = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handleCreateSpace(uid, request.data);
});

export const startDirect = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handleStartDirect(uid, request.data);
});

export const createInvite = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handleCreateInvite(uid, request.data);
});

export const previewInvite = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handlePreviewInvite(uid, request.data);
});

export const joinSpace = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handleJoinSpace(uid, request.data);
});

export const setMyConsent = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handleSetMyConsent(uid, request.data);
});

export const updateAiPolicy = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handleUpdateAiPolicy(uid, request.data);
});

// ============================================================================
// Handoff Pipeline Callables (SPEC C5)
// ============================================================================

export const previewHandoff = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handlePreviewHandoff(uid, request.data);
});

export const runHandoff = onCall(
  { secrets: ["GEMINI_API_KEY"], timeoutSeconds: 90, memory: "512MiB" },
  async (request) => {
    const uid = requireAuth(request);
    return await handleRunHandoff(uid, request.data);
  }
);

// Backward-compat alias for earlier Phase 4 client callers
export const processExplicitHandoff = onCall(
  { secrets: ["GEMINI_API_KEY"], timeoutSeconds: 90, memory: "512MiB" },
  async (request) => {
    const uid = requireAuth(request);
    const { spaceId, messageIds, userPrompt } = request.data;
    const reqId = `compat_${Date.now()}`;
    const preview = await handlePreviewHandoff(uid, { spaceId, messageIds, purpose: userPrompt || "extract" });

    return await handleRunHandoff(uid, {
      spaceId,
      messageIds,
      purpose: userPrompt || "extract",
      requestId: reqId,
      expectedPayloadHash: preview.payloadHash,
      expectedCharterVersion: preview.charterVersion,
    });
  }
);

// ============================================================================
// Acceptance, Items & Board Callables (SPEC C6)
// ============================================================================

export const acceptProposal = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handleAcceptProposal(uid, request.data);
});

export const dismissProposal = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handleDismissProposal(uid, request.data);
});

export const createManualItem = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handleCreateManualItem(uid, request.data);
});

export const updateItem = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handleUpdateItem(uid, request.data);
});

export const respondToAssignment = onCall(async (request) => {
  const uid = requireAuth(request);
  return await handleRespondToAssignment(uid, request.data);
});

// ============================================================================
// Cloud Firestore Trigger: onMessageWritten (SPEC C3)
// ============================================================================

export const onMessageWritten = onDocumentWritten(
  "spaces/{spaceId}/messages/{messageId}",
  async (event) => {
    const spaceId = event.params.spaceId;
    const messageId = event.params.messageId;
    const after = event.data?.after?.data();
    const before = event.data?.before?.data();

    // Ignore deletions
    if (!after) return;

    // Ignore ai* property updates
    if (before && before.text === after.text && before.deletedAt === after.deletedAt) {
      return;
    }

    const spaceRef = db.doc(`spaces/${spaceId}`);
    const isTombstone = after.deletedAt != null || after.text === "";
    let previewText = isTombstone ? "" : after.text.substring(0, 80);

    if (after.kind === "itemCard" && after.itemRef) {
      previewText = `Added ${after.itemRef.type}: ${after.itemRef.title}`.substring(0, 80);
    }

    const lastMessage = {
      messageId,
      preview: previewText,
      senderId: after.senderId,
      createdAt: after.createdAt,
    };

    await spaceRef.update({
      lastActivityAt: after.createdAt || admin.firestore.FieldValue.serverTimestamp(),
      lastMessage,
    });
  }
);
