/**
 * Agora Items & Proposal Acceptance Module
 *
 * Implements SPEC C6 & Phase 4:
 * - acceptProposal (transactional, source verification, no fabricated provenance, idempotency)
 * - dismissProposal (transactional, idempotency)
 * - createManualItem (origin: 'manual', source verification, AI-free fallback)
 * - updateItem (state transitions for task, decision, question)
 * - respondToAssignment (accept/decline)
 */

import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { HttpsError } from "firebase-functions/v2/https";

const db = admin.firestore();
const ID_REGEX = /^[A-Za-z0-9_-]{1,64}$/;

function validateId(id: string, name: string): void {
  if (!id || typeof id !== "string" || !ID_REGEX.test(id)) {
    throw new HttpsError("invalid-argument", `invalid-id: ${name} does not match required format.`);
  }
}

export async function handleAcceptProposal(
  uid: string,
  data: {
    proposalId: string;
    edits?: {
      type?: "task" | "decision" | "question";
      title?: string;
      detail?: string;
      dueDate?: string | null;
      ownerUid?: string | null;
    };
  }
) {
  const { proposalId, edits } = data;
  validateId(proposalId, "proposalId");

  // Validate edit constraints if provided
  if (edits?.title !== undefined) {
    const cleanTitle = edits.title.replace(/<[^>]*>/g, "").trim();
    if (cleanTitle.length === 0 || cleanTitle.length > 120) {
      throw new HttpsError("invalid-argument", "Title must be between 1 and 120 characters.");
    }
  }

  if (edits?.detail !== undefined) {
    const cleanDetail = edits.detail.replace(/<[^>]*>/g, "").trim();
    if (cleanDetail.length > 500) {
      throw new HttpsError("invalid-argument", "Detail must be 500 characters or fewer.");
    }
  }

  if (edits?.dueDate) {
    const parsed = new Date(edits.dueDate);
    const now = new Date();
    const minDate = new Date(now.getTime() - 24 * 3600 * 1000);
    const maxDate = new Date(now.getTime() + 2 * 365 * 24 * 3600 * 1000);
    if (isNaN(parsed.getTime()) || parsed < minDate || parsed > maxDate) {
      throw new HttpsError("invalid-argument", "Due date must be a valid calendar date within [yesterday, +2 years].");
    }
  }

  if (edits?.ownerUid) {
    validateId(edits.ownerUid, "ownerUid");
  }

  return await db.runTransaction(async (transaction) => {
    // 1. Read Proposal (users/{uid}/proposals/{id} primary)
    const userPropRef = db.doc(`users/${uid}/proposals/${proposalId}`);
    let propSnap = await transaction.get(userPropRef);
    let isUserProp = true;

    if (!propSnap.exists) {
      const rootPropRef = db.doc(`proposals/${proposalId}`);
      propSnap = await transaction.get(rootPropRef);
      isUserProp = false;
      if (!propSnap.exists) {
        throw new HttpsError("not-found", "Proposal not found.");
      }
    }

    const prop = propSnap.data()!;

    // Check ownership
    if (prop.createdForUid && prop.createdForUid !== uid) {
      throw new HttpsError("permission-denied", "You do not own this proposal.");
    }

    // Idempotency: return existing itemId if already accepted
    if (prop.status === "accepted") {
      return {
        success: true,
        itemId: prop.acceptedItemId || prop.itemId,
        alreadyAccepted: true,
      };
    }

    if (prop.status !== "pending") {
      throw new HttpsError("failed-precondition", `Cannot accept proposal with status ${prop.status}.`);
    }

    // Expiry check
    if (prop.expiresAt?.toDate && prop.expiresAt.toDate().getTime() < Date.now()) {
      throw new HttpsError("failed-precondition", "Proposal has expired (14-day retention).");
    }

    const spaceId = prop.spaceId;
    validateId(spaceId, "spaceId");

    // 2. Verify caller is still a member of this space
    const memberRef = db.doc(`spaces/${spaceId}/members/${uid}`);
    const memberSnap = await transaction.get(memberRef);
    if (!memberSnap.exists) {
      throw new HttpsError("permission-denied", "You are no longer a member of this space.");
    }

    // 3. Load handoff audit doc and verify caller is the requester
    const handoffRef = db.doc(`spaces/${spaceId}/handoffs/${prop.handoffId}`);
    const handoffSnap = await transaction.get(handoffRef);
    if (!handoffSnap.exists || handoffSnap.data()?.requesterId !== uid) {
      throw new HttpsError("permission-denied", "Only the original handoff requester may accept proposals.");
    }
    const handoffCreatedTime = handoffSnap.data()?.createdAt?.toDate
      ? handoffSnap.data()!.createdAt.toDate().getTime()
      : 0;

    // 4. Verify ownerUid is an active space member if specified
    const targetOwnerUid = edits?.ownerUid !== undefined ? edits.ownerUid : prop.ownerUid;
    if (targetOwnerUid) {
      const ownerMemberRef = db.doc(`spaces/${spaceId}/members/${targetOwnerUid}`);
      const ownerMemberSnap = await transaction.get(ownerMemberRef);
      if (!ownerMemberSnap.exists) {
        throw new HttpsError("invalid-argument", "Designated owner is not a member of this space.");
      }
    }

    // 5. Re-fetch source messages: drop deleted/missing, detect post-handoff edits
    const sourceIds: string[] = Array.isArray(prop.sourceMessageIds) ? prop.sourceMessageIds : [];
    const sourceMessageSnaps = await Promise.all(
      sourceIds.map((id) => transaction.get(db.doc(`spaces/${spaceId}/messages/${id}`)))
    );

    const sourceRefs: Array<{ messageId: string; editedSinceHandoff: boolean }> = [];
    for (const msgSnap of sourceMessageSnaps) {
      if (!msgSnap.exists) continue; // Drop missing messages
      const msg = msgSnap.data()!;
      if (msg.deletedAt != null || !msg.text || msg.text.trim().length === 0) {
        continue; // Drop tombstoned/deleted messages
      }

      const editedTime = msg.editedAt?.toDate ? msg.editedAt.toDate().getTime() : 0;
      const editedSinceHandoff = editedTime > handoffCreatedTime;
      sourceRefs.push({ messageId: msgSnap.id, editedSinceHandoff });
    }

    // Invariant: Never fabricate provenance. If all sources were deleted, reject acceptance.
    if (sourceRefs.length === 0) {
      throw new HttpsError(
        "failed-precondition",
        "sources-unavailable: All source messages have been deleted."
      );
    }

    // 6. Resolve final values
    const itemType = (edits?.type || prop.type || "task") as "task" | "decision" | "question";
    const title = edits?.title ? edits.title.trim() : (prop.title || "Untitled").trim();
    const detail = edits?.detail !== undefined ? edits.detail.trim() : (prop.detail || "").trim();
    const dueDate = edits?.dueDate !== undefined ? edits.dueDate : prop.dueDate || null;

    let ownerState: "unassigned" | "proposed" | "accepted" | "declined" = "unassigned";
    if (targetOwnerUid) {
      ownerState = targetOwnerUid === uid ? "accepted" : "proposed";
    }

    const hasHumanEdits = Boolean(
      edits &&
        (edits.title !== undefined ||
          edits.detail !== undefined ||
          edits.dueDate !== undefined ||
          edits.ownerUid !== undefined ||
          edits.type !== undefined)
    );

    const itemId = `item_${Date.now()}_${crypto.randomBytes(3).toString("hex")}`;
    const now = admin.firestore.FieldValue.serverTimestamp();

    const itemData = {
      id: itemId,
      spaceId,
      type: itemType,
      title,
      detail,
      status: itemType === "decision" ? "active" : "open",
      ownerUid: targetOwnerUid || null,
      ownerState,
      dueDate,
      volunteered: Boolean(prop.volunteered),
      origin: "ai",
      handoffId: prop.handoffId,
      sourceRefs,
      approvedBy: uid,
      approvedAt: now,
      editedByHuman: hasHumanEdits,
      createdBy: uid,
      createdAt: now,
      updatedAt: now,
      updatedBy: uid,
      resolvedAt: null,
    };

    // Chat itemCard message
    const itemCardMsgId = `item_${itemId}`;
    const itemCardMsg = {
      id: itemCardMsgId,
      spaceId,
      senderId: uid,
      kind: "itemCard",
      text: `Added ${itemType}: ${title}`.substring(0, 80),
      itemRef: { itemId, type: itemType, title: title.substring(0, 80) },
      createdAt: now,
    };

    // 7. Atomic Writes
    const itemRef = db.doc(`spaces/${spaceId}/items/${itemId}`);
    transaction.set(itemRef, itemData);

    const updatePropData = {
      status: "accepted",
      acceptedItemId: itemId,
      updatedAt: now,
    };
    transaction.update(userPropRef, updatePropData);

    // Also update root proposal copy if it exists
    const rootPropRef = db.doc(`proposals/${proposalId}`);
    transaction.set(rootPropRef, updatePropData, { merge: true });

    transaction.update(handoffRef, {
      acceptedCount: admin.firestore.FieldValue.increment(1),
    });

    const itemCardRef = db.doc(`spaces/${spaceId}/messages/${itemCardMsgId}`);
    transaction.set(itemCardRef, itemCardMsg);

    return { success: true, itemId, itemCardMsgId };
  });
}

export async function handleDismissProposal(uid: string, data: { proposalId: string }) {
  const { proposalId } = data;
  validateId(proposalId, "proposalId");

  return await db.runTransaction(async (transaction) => {
    const userPropRef = db.doc(`users/${uid}/proposals/${proposalId}`);
    let propSnap = await transaction.get(userPropRef);

    if (!propSnap.exists) {
      const rootPropRef = db.doc(`proposals/${proposalId}`);
      propSnap = await transaction.get(rootPropRef);
      if (!propSnap.exists) {
        throw new HttpsError("not-found", "Proposal not found.");
      }
    }

    const prop = propSnap.data()!;
    if (prop.createdForUid && prop.createdForUid !== uid) {
      throw new HttpsError("permission-denied", "You do not own this proposal.");
    }

    if (prop.status === "dismissed") {
      return { success: true, alreadyDismissed: true };
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const updateData = { status: "dismissed", updatedAt: now };

    transaction.update(userPropRef, updateData);

    const rootPropRef = db.doc(`proposals/${proposalId}`);
    transaction.set(rootPropRef, updateData, { merge: true });

    if (prop.spaceId && prop.handoffId) {
      const handoffRef = db.doc(`spaces/${prop.spaceId}/handoffs/${prop.handoffId}`);
      transaction.update(handoffRef, {
        dismissedCount: admin.firestore.FieldValue.increment(1),
      });
    }

    return { success: true };
  });
}

export async function handleCreateManualItem(
  uid: string,
  data: {
    spaceId: string;
    type: "task" | "decision" | "question";
    title: string;
    detail?: string;
    ownerUid?: string | null;
    dueDate?: string | null;
    sourceMessageIds?: string[];
  }
) {
  const { spaceId, type, title, detail, ownerUid, dueDate, sourceMessageIds } = data;
  validateId(spaceId, "spaceId");

  const cleanTitle = (title || "").replace(/<[^>]*>/g, "").trim();
  if (cleanTitle.length === 0 || cleanTitle.length > 120) {
    throw new HttpsError("invalid-argument", "Title must be between 1 and 120 characters.");
  }

  const cleanDetail = (detail || "").replace(/<[^>]*>/g, "").trim();
  if (cleanDetail.length > 500) {
    throw new HttpsError("invalid-argument", "Detail must be 500 characters or fewer.");
  }

  const validTypes = ["task", "decision", "question"];
  if (!validTypes.includes(type)) {
    throw new HttpsError("invalid-argument", "Invalid item type.");
  }

  const memberSnap = await db.doc(`spaces/${spaceId}/members/${uid}`).get();
  if (!memberSnap.exists) {
    throw new HttpsError("permission-denied", "You must be a member of this space.");
  }

  if (ownerUid) {
    validateId(ownerUid, "ownerUid");
    const ownerMemberSnap = await db.doc(`spaces/${spaceId}/members/${ownerUid}`).get();
    if (!ownerMemberSnap.exists) {
      throw new HttpsError("invalid-argument", "Owner must be a member of this space.");
    }
  }

  // Verify sources that exist and are not deleted in this space
  const sourceRefs: Array<{ messageId: string; editedSinceHandoff: boolean }> = [];
  if (Array.isArray(sourceMessageIds) && sourceMessageIds.length > 0) {
    const snaps = await Promise.all(
      sourceMessageIds.map((id) => db.doc(`spaces/${spaceId}/messages/${id}`).get())
    );
    for (const snap of snaps) {
      if (snap.exists && snap.data()?.deletedAt == null) {
        sourceRefs.push({ messageId: snap.id, editedSinceHandoff: false });
      }
    }
  }

  const itemId = `item_man_${Date.now()}_${crypto.randomBytes(3).toString("hex")}`;
  const now = admin.firestore.FieldValue.serverTimestamp();

  let ownerState: "unassigned" | "proposed" | "accepted" | "declined" = "unassigned";
  if (ownerUid) {
    ownerState = ownerUid === uid ? "accepted" : "proposed";
  }

  const itemData = {
    id: itemId,
    spaceId,
    type,
    title: cleanTitle,
    detail: cleanDetail,
    status: type === "decision" ? "active" : "open",
    ownerUid: ownerUid || null,
    ownerState,
    dueDate: dueDate || null,
    volunteered: false,
    origin: "manual",
    handoffId: null,
    sourceRefs,
    approvedBy: uid,
    approvedAt: now,
    editedByHuman: false,
    createdBy: uid,
    createdAt: now,
    updatedAt: now,
    updatedBy: uid,
    resolvedAt: null,
  };

  const itemCardMsgId = `item_${itemId}`;
  const itemCardMsg = {
    id: itemCardMsgId,
    spaceId,
    senderId: uid,
    kind: "itemCard",
    text: `Added ${type}: ${cleanTitle}`.substring(0, 80),
    itemRef: { itemId, type, title: cleanTitle.substring(0, 80) },
    createdAt: now,
  };

  const batch = db.batch();
  batch.set(db.doc(`spaces/${spaceId}/items/${itemId}`), itemData);
  batch.set(db.doc(`spaces/${spaceId}/messages/${itemCardMsgId}`), itemCardMsg);
  await batch.commit();

  return { success: true, itemId, itemCardMsgId };
}

export async function handleUpdateItem(
  uid: string,
  data: {
    spaceId: string;
    itemId: string;
    action: "complete" | "reopen" | "drop" | "supersede" | "reactivate" | "answer" | "dismiss";
  }
) {
  const { spaceId, itemId, action } = data;
  validateId(spaceId, "spaceId");
  validateId(itemId, "itemId");

  const memberSnap = await db.doc(`spaces/${spaceId}/members/${uid}`).get();
  if (!memberSnap.exists) {
    throw new HttpsError("permission-denied", "You must be a member of this space.");
  }

  const itemRef = db.doc(`spaces/${spaceId}/items/${itemId}`);
  const itemSnap = await itemRef.get();
  if (!itemSnap.exists) {
    throw new HttpsError("not-found", "Item not found.");
  }
  const item = itemSnap.data()!;

  let newStatus = item.status;
  let isResolved = false;

  if (item.type === "task") {
    if (action === "complete") {
      newStatus = "done";
      isResolved = true;
    } else if (action === "reopen") {
      newStatus = "open";
    } else if (action === "drop") {
      newStatus = "dropped";
      isResolved = true;
    } else {
      throw new HttpsError("invalid-argument", `Invalid action '${action}' for task.`);
    }
  } else if (item.type === "decision") {
    if (action === "supersede") {
      newStatus = "superseded";
      isResolved = true;
    } else if (action === "reactivate") {
      newStatus = "active";
    } else {
      throw new HttpsError("invalid-argument", `Invalid action '${action}' for decision.`);
    }
  } else if (item.type === "question") {
    if (action === "answer") {
      newStatus = "answered";
      isResolved = true;
    } else if (action === "reopen") {
      newStatus = "open";
    } else if (action === "dismiss") {
      newStatus = "dismissed";
      isResolved = true;
    } else {
      throw new HttpsError("invalid-argument", `Invalid action '${action}' for question.`);
    }
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  await itemRef.update({
    status: newStatus,
    updatedAt: now,
    updatedBy: uid,
    resolvedAt: isResolved ? now : null,
  });

  return { success: true, newStatus };
}

export async function handleRespondToAssignment(
  uid: string,
  data: { spaceId: string; itemId: string; accept: boolean }
) {
  const { spaceId, itemId, accept } = data;
  validateId(spaceId, "spaceId");
  validateId(itemId, "itemId");

  const itemRef = db.doc(`spaces/${spaceId}/items/${itemId}`);
  const itemSnap = await itemRef.get();
  if (!itemSnap.exists) throw new HttpsError("not-found", "Item not found.");
  const item = itemSnap.data()!;

  if (item.ownerUid !== uid) {
    throw new HttpsError("permission-denied", "You are not the designated owner of this item.");
  }

  if (item.ownerState !== "proposed") {
    throw new HttpsError("failed-precondition", "Item assignment is not pending confirmation.");
  }

  const newOwnerState = accept ? "accepted" : "declined";
  const newOwnerUid = accept ? uid : null;

  await itemRef.update({
    ownerState: newOwnerState,
    ownerUid: newOwnerUid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: uid,
  });

  return { success: true, ownerState: newOwnerState };
}
