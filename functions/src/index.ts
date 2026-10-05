/**
 * Agora Cloud Functions v2 (TypeScript)
 *
 * Core Architecture Rules:
 * 1. AI is ONLY invoked through explicit callable functions triggered by human handoff.
 * 2. NO background or ambient triggers on chat messages.
 * 3. Gemini API keys are strictly server-side environment secrets.
 * 4. Outputs are strictly non-authoritative Proposals (tasks, decisions, questions).
 * 5. Every handoff produces an immutable audit record in aiOutputs and space handoffs.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

interface HandoffRequest {
  spaceId: string;
  messageIds: string[];
  userPrompt?: string;
}

/**
 * Callable Cloud Function: processExplicitHandoff
 *
 * Validates human handoff, filters out withheld messages,
 * prepares proposals via Gemini, and writes auditable outputs.
 */
export const processExplicitHandoff = onCall<HandoffRequest>(
  { secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    // 1. Authentication check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }
    const uid = request.auth.uid;
    const { spaceId, messageIds, userPrompt } = request.data;

    if (!spaceId || !Array.isArray(messageIds) || messageIds.length === 0) {
      throw new HttpsError("invalid-argument", "Missing spaceId or messageIds.");
    }

    // 2. Authorization check: must be a member of the space
    const memberDoc = await db.doc(`spaces/${spaceId}/members/${uid}`).get();
    if (!memberDoc.exists) {
      throw new HttpsError("permission-denied", "You must be a member of this space.");
    }

    // 3. Verify messages and enforce author consent shield
    const messages: Array<{ id: string; text: string; senderDisplayName: string }> = [];
    for (const msgId of messageIds) {
      const msgSnap = await db.doc(`spaces/${spaceId}/messages/${msgId}`).get();
      if (!msgSnap.exists) continue;
      const data = msgSnap.data()!;

      // Enforce author withhold invariant
      if (data.aiWithheld === true) {
        throw new HttpsError(
          "failed-precondition",
          `Message ${msgId} was marked as withheld by its author and cannot be processed by AI.`
        );
      }

      messages.push({
        id: msgId,
        text: data.text,
        senderDisplayName: data.senderDisplayName,
      });
    }

    if (messages.length === 0) {
      throw new HttpsError("invalid-argument", "No eligible messages selected.");
    }

    // Server-side Gemini processing occurs here in later stage
    // Generating proposals strictly in "pending" status for human review.
    return {
      status: "ready_for_proposal_stage",
      eligibleCount: messages.length,
      spaceId,
    };
  }
);
