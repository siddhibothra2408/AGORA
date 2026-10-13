/**
 * Agora Spaces & Membership Lifecycle Module
 *
 * Implements SPEC C2:
 * - createSpace (group with explicit consent, charterVersion 1)
 * - startDirect (deterministic dm_uidA_uidB id, other user pending)
 * - previewInvite & joinSpace (30 cap in-transaction, charter-changed check)
 * - createInvite, listInvites, revokeInvite
 * - setMyConsent (charter-changed check)
 * - updateAiPolicy (expansion resets 'allowed' -> 'pending' and bumps version; narrowing does not)
 * - setMemberRole, removeMember, leaveSpace (protects last admin)
 */

import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { HttpsError } from "firebase-functions/v2/https";
import {
  AiConsentState,
  AiHandoffPolicy,
  isExpansion,
  SpaceData,
} from "./consent";

const db = admin.firestore();

const ID_REGEX = /^[A-Za-z0-9_-]{1,64}$/;
const INVITE_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function generateInviteCode(): string {
  const bytes = crypto.randomBytes(10);
  let code = "";
  for (let i = 0; i < 10; i++) {
    code += INVITE_CODE_CHARS[bytes[i] % INVITE_CODE_CHARS.length];
  }
  return code;
}

export async function handleCreateSpace(
  uid: string,
  data: {
    name: string;
    emoji?: string;
    colorKey?: string;
    aiHandoffPolicy?: AiHandoffPolicy;
    creatorConsent: AiConsentState;
  }
) {
  if (!data.name || data.name.trim().length === 0 || data.name.length > 100) {
    throw new HttpsError("invalid-argument", "Valid space name is required (max 100 chars).");
  }
  if (!data.creatorConsent || !["allowed", "withheld"].includes(data.creatorConsent)) {
    throw new HttpsError(
      "invalid-argument",
      "Explicit creator consent choice is required ('allowed' or 'withheld')."
    );
  }

  const spaceId = `space_${Date.now()}_${crypto.randomBytes(4).toString("hex")}`;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const policy: AiHandoffPolicy = data.aiHandoffPolicy || "anyone";

  const spaceDoc: SpaceData = {
    id: spaceId,
    kind: "group",
    name: data.name.trim(),
    emoji: data.emoji || "💬",
    colorKey: data.colorKey || "aegean",
    createdBy: uid,
    createdAt: now,
    lastActivityAt: now,
    memberIds: [uid],
    memberCount: 1,
    aiPolicy: {
      handoff: policy,
      maxSessionMinutes: 60,
    },
    charterVersion: 1,
    lastMessage: null,
  };

  const memberDoc = {
    uid,
    role: "owner",
    joinedAt: now,
    aiConsent: data.creatorConsent,
    consentCharterVersion: 1,
    consentUpdatedAt: now,
    lastReadAt: now,
  };

  const batch = db.batch();
  batch.set(db.doc(`spaces/${spaceId}`), spaceDoc);
  batch.set(db.doc(`spaces/${spaceId}/members/${uid}`), memberDoc);
  await batch.commit();

  return { spaceId, charterVersion: 1 };
}

export async function handleStartDirect(
  uid: string,
  data: { handle: string; myConsent: AiConsentState }
) {
  const targetHandle = (data.handle || "").trim().toLowerCase().replace(/^@/, "");
  if (!targetHandle) {
    throw new HttpsError("invalid-argument", "Valid recipient handle is required.");
  }
  if (!data.myConsent || !["allowed", "withheld"].includes(data.myConsent)) {
    throw new HttpsError("invalid-argument", "Explicit consent choice is required.");
  }

  // Lookup target user
  const usersSnap = await db
    .collection("users")
    .where("handle", "==", targetHandle)
    .limit(1)
    .get();

  if (usersSnap.empty) {
    throw new HttpsError("not-found", "User handle not found.");
  }

  const targetDoc = usersSnap.docs[0];
  const targetUid = targetDoc.id;

  if (targetUid === uid) {
    throw new HttpsError("invalid-argument", "Cannot start a direct space with yourself.");
  }

  // Deterministic ID: dm_ sorted uids
  const sortedUids = [uid, targetUid].sort();
  const directSpaceId = `dm_${sortedUids[0]}_${sortedUids[1]}`;
  const now = admin.firestore.FieldValue.serverTimestamp();

  const spaceRef = db.doc(`spaces/${directSpaceId}`);
  const existing = await spaceRef.get();

  if (existing.exists) {
    return { spaceId: directSpaceId, existing: true };
  }

  const spaceDoc: SpaceData = {
    id: directSpaceId,
    kind: "direct",
    name: null,
    emoji: "🔒",
    colorKey: "navy",
    createdBy: uid,
    createdAt: now,
    lastActivityAt: now,
    memberIds: sortedUids,
    memberCount: 2,
    aiPolicy: { handoff: "anyone", maxSessionMinutes: 60 },
    charterVersion: 1,
    lastMessage: null,
  };

  const batch = db.batch();
  batch.set(spaceRef, spaceDoc);
  batch.set(db.doc(`spaces/${directSpaceId}/members/${uid}`), {
    uid,
    role: "member",
    joinedAt: now,
    aiConsent: data.myConsent,
    consentCharterVersion: 1,
    consentUpdatedAt: now,
    lastReadAt: now,
  });
  batch.set(db.doc(`spaces/${directSpaceId}/members/${targetUid}`), {
    uid: targetUid,
    role: "member",
    joinedAt: now,
    aiConsent: "pending",
    consentCharterVersion: null,
    consentUpdatedAt: now,
    lastReadAt: null,
  });

  await batch.commit();
  return { spaceId: directSpaceId, existing: false };
}

export async function handleCreateInvite(
  uid: string,
  data: { spaceId: string; expiresInHours?: number; maxUses?: number }
) {
  const { spaceId } = data;
  if (!ID_REGEX.test(spaceId)) {
    throw new HttpsError("invalid-argument", "Invalid space ID.");
  }

  const memberSnap = await db.doc(`spaces/${spaceId}/members/${uid}`).get();
  if (!memberSnap.exists) {
    throw new HttpsError("permission-denied", "Not a member of this space.");
  }
  const role = memberSnap.data()?.role;
  if (role !== "admin" && role !== "owner") {
    throw new HttpsError("permission-denied", "Admin or Owner role required to create invites.");
  }

  const code = generateInviteCode();
  const hours = data.expiresInHours && data.expiresInHours > 0 ? data.expiresInHours : 24 * 7;
  const expiresAt = new Date(Date.now() + hours * 3600 * 1000);
  const maxUses = data.maxUses && data.maxUses > 0 ? data.maxUses : 30;

  await db.doc(`invites/${code}`).set({
    code,
    spaceId,
    createdBy: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    maxUses,
    uses: 0,
    revoked: false,
  });

  return { code, expiresAt: expiresAt.toISOString(), maxUses };
}

export async function handlePreviewInvite(uid: string, data: { code: string }) {
  const code = (data.code || "").trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (code.length < 5) {
    throw new HttpsError("invalid-argument", "Invalid invite code format.");
  }

  const snap = await db.doc(`invites/${code}`).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Invite not found or expired.");
  }
  const inv = snap.data()!;
  if (inv.revoked) {
    throw new HttpsError("failed-precondition", "This invite has been revoked.");
  }
  if (inv.expiresAt && inv.expiresAt.toDate() < new Date()) {
    throw new HttpsError("failed-precondition", "This invite has expired.");
  }
  if (inv.maxUses && inv.uses >= inv.maxUses) {
    throw new HttpsError("failed-precondition", "This invite has reached its maximum uses.");
  }

  const spaceSnap = await db.doc(`spaces/${inv.spaceId}`).get();
  if (!spaceSnap.exists) {
    throw new HttpsError("not-found", "Associated space no longer exists.");
  }
  const spaceData = spaceSnap.data()!;

  return {
    code,
    spaceId: inv.spaceId,
    spaceName: spaceData.name,
    memberCount: spaceData.memberCount || 1,
    charterVersion: spaceData.charterVersion || 1,
    aiPolicy: spaceData.aiPolicy,
  };
}

export async function handleJoinSpace(
  uid: string,
  data: { code: string; consent: AiConsentState; expectedCharterVersion: number }
) {
  const code = (data.code || "").trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (!code) throw new HttpsError("invalid-argument", "Invite code is required.");
  if (!data.consent || !["allowed", "withheld"].includes(data.consent)) {
    throw new HttpsError("invalid-argument", "Explicit consent choice required ('allowed' or 'withheld').");
  }

  return await db.runTransaction(async (tx) => {
    const inviteRef = db.doc(`invites/${code}`);
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new HttpsError("not-found", "Invite code not found.");
    }
    const inv = inviteSnap.data()!;
    if (inv.revoked || (inv.expiresAt && inv.expiresAt.toDate() < new Date())) {
      throw new HttpsError("failed-precondition", "Invite expired or revoked.");
    }
    if (inv.maxUses && inv.uses >= inv.maxUses) {
      throw new HttpsError("failed-precondition", "Invite max uses reached.");
    }

    const spaceRef = db.doc(`spaces/${inv.spaceId}`);
    const spaceSnap = await tx.get(spaceRef);
    if (!spaceSnap.exists) {
      throw new HttpsError("not-found", "Space not found.");
    }
    const space = spaceSnap.data()!;

    // Check charter version
    if (data.expectedCharterVersion !== space.charterVersion) {
      throw new HttpsError(
        "failed-precondition",
        `Charter version has changed (current: ${space.charterVersion}, expected: ${data.expectedCharterVersion}). Please review new charter.`
      );
    }

    const memberRef = db.doc(`spaces/${inv.spaceId}/members/${uid}`);
    const memberSnap = await tx.get(memberRef);

    // If already member, idempotent update
    const now = admin.firestore.FieldValue.serverTimestamp();
    if (memberSnap.exists) {
      tx.update(memberRef, {
        aiConsent: data.consent,
        consentCharterVersion: space.charterVersion,
        consentUpdatedAt: now,
      });
      return { spaceId: inv.spaceId, alreadyMember: true };
    }

    // Check 30 cap
    const currentCount = space.memberCount || (space.memberIds?.length || 0);
    if (currentCount >= 30) {
      throw new HttpsError("resource-exhausted", "Space has reached maximum 30 members.");
    }

    // Add member & increment uses
    tx.set(memberRef, {
      uid,
      role: "member",
      joinedAt: now,
      aiConsent: data.consent,
      consentCharterVersion: space.charterVersion,
      consentUpdatedAt: now,
      lastReadAt: now,
    });

    tx.update(spaceRef, {
      memberIds: admin.firestore.FieldValue.arrayUnion(uid),
      memberCount: admin.firestore.FieldValue.increment(1),
      lastActivityAt: now,
    });

    tx.update(inviteRef, {
      uses: admin.firestore.FieldValue.increment(1),
    });

    return { spaceId: inv.spaceId, alreadyMember: false };
  });
}

export async function handleSetMyConsent(
  uid: string,
  data: { spaceId: string; consent: AiConsentState; expectedCharterVersion: number }
) {
  const { spaceId, consent, expectedCharterVersion } = data;
  if (!ID_REGEX.test(spaceId)) throw new HttpsError("invalid-argument", "Invalid space ID.");
  if (!["allowed", "withheld"].includes(consent)) {
    throw new HttpsError("invalid-argument", "Consent must be 'allowed' or 'withheld'.");
  }

  const spaceSnap = await db.doc(`spaces/${spaceId}`).get();
  if (!spaceSnap.exists) throw new HttpsError("not-found", "Space not found.");
  const space = spaceSnap.data()!;

  if (space.charterVersion !== expectedCharterVersion) {
    throw new HttpsError(
      "failed-precondition",
      `Charter version changed to ${space.charterVersion}. Re-review charter before consenting.`
    );
  }

  const memberRef = db.doc(`spaces/${spaceId}/members/${uid}`);
  const memberSnap = await memberRef.get();
  if (!memberSnap.exists) throw new HttpsError("permission-denied", "Not a member of this space.");

  await memberRef.update({
    aiConsent: consent,
    consentCharterVersion: space.charterVersion,
    consentUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, charterVersion: space.charterVersion };
}

export async function handleUpdateAiPolicy(
  uid: string,
  data: { spaceId: string; handoff: AiHandoffPolicy }
) {
  const { spaceId, handoff } = data;
  if (!ID_REGEX.test(spaceId)) throw new HttpsError("invalid-argument", "Invalid space ID.");
  if (!["anyone", "admins", "off"].includes(handoff)) {
    throw new HttpsError("invalid-argument", "Invalid handoff policy.");
  }

  const memberSnap = await db.doc(`spaces/${spaceId}/members/${uid}`).get();
  if (!memberSnap.exists) throw new HttpsError("permission-denied", "Not a member.");
  const role = memberSnap.data()?.role;
  if (role !== "admin" && role !== "owner") {
    throw new HttpsError("permission-denied", "Admin or owner role required to update policy.");
  }

  const spaceRef = db.doc(`spaces/${spaceId}`);
  return await db.runTransaction(async (tx) => {
    const spaceSnap = await tx.get(spaceRef);
    if (!spaceSnap.exists) throw new HttpsError("not-found", "Space not found.");
    const space = spaceSnap.data()!;

    const currentPolicy: AiHandoffPolicy = space.aiPolicy?.handoff || "anyone";
    if (currentPolicy === handoff) {
      return { noop: true, charterVersion: space.charterVersion };
    }

    const expansion = isExpansion(currentPolicy, handoff);
    const newCharterVersion = expansion ? (space.charterVersion || 1) + 1 : space.charterVersion;

    tx.update(spaceRef, {
      "aiPolicy.handoff": handoff,
      charterVersion: newCharterVersion,
      lastActivityAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // If EXPANSION: reset all 'allowed' members to 'pending'
    if (expansion) {
      const membersSnap = await db
        .collection(`spaces/${spaceId}/members`)
        .where("aiConsent", "==", "allowed")
        .get();

      for (const mDoc of membersSnap.docs) {
        tx.update(mDoc.ref, {
          aiConsent: "pending",
          consentUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    return { expansion, newCharterVersion };
  });
}
