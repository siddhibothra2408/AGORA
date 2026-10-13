/**
 * Agora Items & Proposal Acceptance Module
 *
 * Implements SPEC C6:
 * - acceptProposal (verifies sources, flags editedSinceHandoff, writes item + itemCard)
 * - dismissProposal
 * - createManualItem (origin: 'manual')
 * - updateItem (state transitions for task, decision, question)
 * - respondToAssignment (accept/decline)
 */

import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { HttpsError } from "firebase-functions/v2/https";

const db = admin.firestore();

export async function handleAcceptProposal(
  uid: string,
  data: {
    proposalId: string;
    edits?: {
      title?: string;
      detail?: string;
      dueDate?: string | null;
      ownerUid?: string | null;
    };
  }
) {
  const { proposalId, edits } = data;
  const propRef = db.doc(`users/${uid}/proposals/${proposalId}`);
  const propSnap = await propRef.get();

  if (!propSnap.exists) {
    throw new HttpsError("not-found", "Proposal not found.");
  }
  const prop = propSnap.data()!;

  if (prop.status === "accepted") {
    return { success: true, alreadyAccepted: true };
  }
  if (prop.status !== "pending") {
    throw new HttpsError("failed-precondition", `Cannot accept proposal with status ${prop.status}.`);
  }

  const spaceId = prop.spaceId;
  const memberSnap = await db.doc(`spaces/${spaceId}/members/${uid}`).get();
  if (!memberSnap.exists) {
    throw new HttpsError("permission-denied", "You are no longer a member of this space.");
  }

  // Load handoff to compare timestamps
  const handoffRef = db.doc(`spaces/${spaceId}/handoffs/${prop.handoffId}`);
  const handoffSnap = await handoffRef.get();
  const handoffCreatedTime = handoffSnap.data()?.createdAt?.toDate
    ? handoffSnap.data()!.createdAt.toDate().getTime()
    : 0;

  // Re-fetch source messages: drop deleted, flag editedSinceHandoff
  const sourceRefs: Array<{ messageId: string; editedSinceHandoff: boolean }> = [];
  for (const msgId of prop.sourceMessageIds || []) {
    const msgSnap = await db.doc(`spaces/${spaceId}/messages/${msgId}`).get();
    if (!msgSnap.exists) continue;
    const msg = msgSnap.data()!;
    if (msg.deletedAt != null) continue; // Drop deleted messages

    const editedTime = msg.editedAt?.toDate ? msg.editedAt.toDate().getTime() : 0;
    const editedSinceHandoff = editedTime > handoffCreatedTime;
    sourceRefs.push({ messageId: msgId, editedSinceHandoff });
  }

  if (sourceRefs.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "sources-unavailable: All source messages have been deleted."
    );
  }

  // Resolve values (with edits if provided)
  const title = edits?.title ? edits.title.trim() : prop.title;
  const detail = edits?.detail !== undefined ? edits.detail.trim() : prop.detail;
  const dueDate = edits?.dueDate !== undefined ? edits.dueDate : prop.dueDate;
  const targetOwnerUid = edits?.ownerUid !== undefined ? edits.ownerUid : prop.ownerUid;

  let ownerState: "unassigned" | "proposed" | "accepted" | "declined" = "unassigned";
  if (targetOwnerUid) {
    ownerState = targetOwnerUid === uid ? "accepted" : "proposed";
  }

  const itemId = `item_${Date.now()}_${crypto.randomBytes(3).toString("hex")}`;
  const now = admin.firestore.FieldValue.serverTimestamp();

  const itemData = {
    id: itemId,
    spaceId,
    type: prop.type,
    title,
    detail,
    status: prop.type === "decision" ? "active" : "open",
    ownerUid: targetOwnerUid || null,
    ownerState,
    dueDate: dueDate || null,
    volunteered: Boolean(prop.volunteered),
    origin: "ai",
    handoffId: prop.handoffId,
    sourceRefs,
    approvedBy: uid,
    approvedAt: now,
    editedByHuman: Boolean(edits),
    createdBy: uid,
    createdAt: now,
    updatedAt: now,
    updatedBy: uid,
  };

  // Chat itemCard message
  const itemCardMsgId = `item_${itemId}`;
  const itemCardMsg = {
    id: itemCardMsgId,
    spaceId,
    senderId: uid,
    kind: "itemCard",
    text: `Added ${prop.type}: ${title}`,
    itemRef: { itemId, type: prop.type, title },
    createdAt: now,
  };

  const batch = db.batch();
  batch.set(db.doc(`spaces/${spaceId}/items/${itemId}`), itemData);
  batch.update(propRef, { status: "accepted", acceptedItemId: itemId, updatedAt: now });
  batch.update(handoffRef, { acceptedCount: admin.firestore.FieldValue.increment(1) });
  batch.set(db.doc(`spaces/${spaceId}/messages/${itemCardMsgId}`), itemCardMsg);
  await batch.commit();

  return { success: true, itemId, itemCardMsgId };
}

export async function handleDismissProposal(uid: string, data: { proposalId: string }) {
  const { proposalId } = data;
  const propRef = db.doc(`users/${uid}/proposals/${proposalId}`);
  const propSnap = await propRef.get();
  if (!propSnap.exists) {
    throw new HttpsError("not-found", "Proposal not found.");
  }
  const prop = propSnap.data()!;
  if (prop.status === "dismissed") return { success: true, alreadyDismissed: true };

  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();
  batch.update(propRef, { status: "dismissed", updatedAt: now });
  batch.update(db.doc(`spaces/${prop.spaceId}/handoffs/${prop.handoffId}`), {
    dismissedCount: admin.firestore.FieldValue.increment(1),
  });
  await batch.commit();

  return { success: true };
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
  const memberSnap = await db.doc(`spaces/${spaceId}/members/${uid}`).get();
  if (!memberSnap.exists) {
    throw new HttpsError("permission-denied", "You must be a member of this space.");
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
    title: title.trim(),
    detail: (detail || "").trim(),
    status: type === "decision" ? "active" : "open",
    ownerUid: ownerUid || null,
    ownerState,
    dueDate: dueDate || null,
    volunteered: false,
    origin: "manual",
    handoffId: null,
    sourceRefs: (sourceMessageIds || []).map((id) => ({ messageId: id, editedSinceHandoff: false })),
    approvedBy: uid,
    approvedAt: now,
    editedByHuman: false,
    createdBy: uid,
    createdAt: now,
    updatedAt: now,
    updatedBy: uid,
  };

  const itemCardMsgId = `item_${itemId}`;
  const itemCardMsg = {
    id: itemCardMsgId,
    spaceId,
    senderId: uid,
    kind: "itemCard",
    text: `Added ${type}: ${title.trim()}`,
    itemRef: { itemId, type, title: title.trim() },
    createdAt: now,
  };

  const batch = db.batch();
  batch.set(db.doc(`spaces/${spaceId}/items/${itemId}`), itemData);
  batch.set(db.doc(`spaces/${spaceId}/messages/${itemCardMsgId}`), itemCardMsg);
  await batch.commit();

  return { success: true, itemId };
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
  const itemRef = db.doc(`spaces/${spaceId}/items/${itemId}`);
  const itemSnap = await itemRef.get();
  if (!itemSnap.exists) {
    throw new HttpsError("not-found", "Item not found.");
  }
  const item = itemSnap.data()!;

  let newStatus = item.status;
  if (item.type === "task") {
    if (action === "complete") newStatus = "done";
    else if (action === "reopen") newStatus = "open";
    else if (action === "drop") newStatus = "dropped";
    else throw new HttpsError("invalid-argument", `Invalid action ${action} for task.`);
  } else if (item.type === "decision") {
    if (action === "supersede") newStatus = "superseded";
    else if (action === "reactivate") newStatus = "active";
    else throw new HttpsError("invalid-argument", `Invalid action ${action} for decision.`);
  } else if (item.type === "question") {
    if (action === "answer") newStatus = "answered";
    else if (action === "reopen") newStatus = "open";
    else if (action === "dismiss") newStatus = "dismissed";
    else throw new HttpsError("invalid-argument", `Invalid action ${action} for question.`);
  }

  await itemRef.update({
    status: newStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: uid,
  });

  return { success: true, newStatus };
}

export async function handleRespondToAssignment(
  uid: string,
  data: { spaceId: string; itemId: string; accept: boolean }
) {
  const { spaceId, itemId, accept } = data;
  const itemRef = db.doc(`spaces/${spaceId}/items/${itemId}`);
  const itemSnap = await itemRef.get();
  if (!itemSnap.exists) throw new HttpsError("not-found", "Item not found.");
  const item = itemSnap.data()!;

  if (item.ownerUid !== uid) {
    throw new HttpsError("permission-denied", "You are not the designated owner of this item.");
  }

  const newOwnerState = accept ? "accepted" : "declined";
  await itemRef.update({
    ownerState: newOwnerState,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: uid,
  });

  return { success: true, ownerState: newOwnerState };
}
