/**
 * Agora Shared Consent & Handoff Policy Module
 *
 * Core Invariant:
 * AI has zero ambient access. Only explicitly handed-off messages can be sent.
 *
 * BINDING OWN-MESSAGE EXCEPTION:
 * A requester may include their OWN messages in a handoff even if they personally
 * withheld consent for other members' handoffs.
 * This applies ONLY to the requester's own messages (authorUid === requesterUid)
 * and NEVER lets anyone include another author's withheld, pending, or stale-consent messages.
 */

import * as crypto from "crypto";

export type AiConsentState = "allowed" | "withheld" | "pending";
export type AiHandoffPolicy = "anyone" | "admins" | "off";
export type SpaceMemberRole = "owner" | "admin" | "member";

export interface SpaceData {
  id: string;
  kind?: "group" | "direct";
  name?: string | null;
  emoji?: string;
  colorKey?: string;
  createdBy?: string;
  createdAt?: any;
  lastActivityAt?: any;
  memberIds?: string[];
  memberCount?: number;
  aiPolicy?: {
    handoff: AiHandoffPolicy;
    maxSessionMinutes?: number;
  };
  charterVersion: number;
  lastMessage?: any;
}

export interface SpaceMemberData {
  uid: string;
  role: SpaceMemberRole;
  joinedAt?: any;
  aiConsent: AiConsentState;
  consentCharterVersion?: number | null;
  consentUpdatedAt?: any;
  lastReadAt?: any;
  displayName?: string;
  handle?: string;
}

export interface MessageData {
  id: string;
  senderId: string;
  kind?: "text" | "itemCard";
  text: string;
  createdAt?: any;
  replyToId?: string;
  editedAt?: any;
  deletedAt?: any;
  aiSeenCount?: number;
  aiWithheld?: boolean; // Author client-side flag backward-compat
}

export type HandoffEvaluationReason =
  | "included-own"
  | "included-consented"
  | "excluded-withheld"
  | "excluded-deleted"
  | "excluded-invalid";

export const AI_POLICY_RANK: Record<AiHandoffPolicy, number> = {
  off: 0,
  admins: 1,
  anyone: 2,
};

/**
 * Computes a member's effective consent status relative to the current Space Charter.
 * Returns 'allowed' ONLY if aiConsent === 'allowed' AND consentCharterVersion === space.charterVersion.
 * Pending, stale, or missing consent all evaluate to 'withheld'.
 */
export function effectiveConsent(
  member: SpaceMemberData | null | undefined,
  space: SpaceData
): AiConsentState {
  if (!member) return "withheld";
  if (member.aiConsent === "allowed" && member.consentCharterVersion === space.charterVersion) {
    return "allowed";
  }
  return "withheld";
}

/**
 * Enforces the binding OWN-MESSAGE EXCEPTION.
 * A requester may include their own messages even if their own consent is withheld.
 * Another author's messages require effectiveConsent === 'allowed'.
 */
export function canIncludeMessage(params: {
  authorUid: string;
  requesterUid: string;
  authorEffectiveConsent: AiConsentState;
}): boolean {
  if (params.authorUid === params.requesterUid) {
    return true; // BINDING OWN-MESSAGE EXCEPTION
  }
  return params.authorEffectiveConsent === "allowed";
}

/**
 * Evaluates a single message for inclusion in a handoff.
 */
export function evaluateMessageForHandoff(params: {
  message: MessageData;
  authorMember: SpaceMemberData | null | undefined;
  requesterUid: string;
  space: SpaceData;
}): { canInclude: boolean; reason: HandoffEvaluationReason } {
  const { message, authorMember, requesterUid, space } = params;

  // 1. Check for deleted or tombstoned messages
  if (message.deletedAt != null || !message.text || message.text.trim().length === 0) {
    return { canInclude: false, reason: "excluded-deleted" };
  }

  // 2. Reject non-text kinds (e.g. item cards)
  if (message.kind && message.kind !== "text") {
    return { canInclude: false, reason: "excluded-invalid" };
  }

  // 3. Own-message exception
  if (message.senderId === requesterUid) {
    return { canInclude: true, reason: "included-own" };
  }

  // 4. Author consent check
  const effConsent = effectiveConsent(authorMember, space);
  if (effConsent === "allowed" && message.aiWithheld !== true) {
    return { canInclude: true, reason: "included-consented" };
  }

  return { canInclude: false, reason: "excluded-withheld" };
}

/**
 * Checks whether the space's AI policy permits the requester's role to execute a handoff.
 */
export function policyPermitsHandoff(
  space: SpaceData,
  role: SpaceMemberRole
): boolean {
  const policy = space.aiPolicy?.handoff || "anyone";
  if (policy === "off") return false;
  if (policy === "admins") return role === "admin" || role === "owner";
  return true;
}

/**
 * Checks if a proposed policy change is an expansion.
 */
export function isExpansion(
  oldPolicy: AiHandoffPolicy,
  newPolicy: AiHandoffPolicy
): boolean {
  return AI_POLICY_RANK[newPolicy] > AI_POLICY_RANK[oldPolicy];
}

/**
 * Sanitizes and redacts content to preserve privacy:
 * - Emails -> [email]
 * - Phones -> [phone]
 * - 9+ digit runs -> [number]
 * - URLs -> [link]
 */
export function redactContent(text: string): string {
  if (!text) return "";
  let redacted = text;

  // Emails
  redacted = redacted.replace(
    /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g,
    "[email]"
  );

  // URLs
  redacted = redacted.replace(
    /https?:\/\/[^\s/$.?#].[^\s]*/gi,
    "[link]"
  );

  // Phone numbers (common international and national patterns)
  redacted = redacted.replace(
    /(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b/g,
    "[phone]"
  );

  // 9+ digit runs (account numbers, IDs)
  redacted = redacted.replace(/\b\d{9,}\b/g, "[number]");

  return redacted;
}

/**
 * Computes canonical SHA-256 hash over the payload, charterVersion, policy, and purpose.
 */
export function computePayloadHash(
  payload: Array<{ token: string; authorLabel: string; timestampIso: string; text: string }>,
  charterVersion: number,
  policy: string,
  purpose: string
): string {
  const canonicalData = {
    payload,
    charterVersion,
    policy,
    purpose,
  };
  const jsonStr = JSON.stringify(canonicalData);
  return crypto.createHash("sha256").update(jsonStr, "utf8").digest("hex");
}
