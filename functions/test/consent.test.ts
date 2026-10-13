import {
  effectiveConsent,
  canIncludeMessage,
  evaluateMessageForHandoff,
  policyPermitsHandoff,
  isExpansion,
  redactContent,
  computePayloadHash,
  SpaceData,
  SpaceMemberData,
  MessageData,
} from "../src/consent";

describe("Agora Consent & Policy Engine Tests", () => {
  const baseSpace: SpaceData = {
    id: "space_test",
    charterVersion: 2,
    aiPolicy: { handoff: "anyone" },
  };

  describe("effectiveConsent", () => {
    it("returns allowed only when consent is allowed AND charterVersion matches", () => {
      const memberAllowed: SpaceMemberData = {
        uid: "user_1",
        role: "member",
        aiConsent: "allowed",
        consentCharterVersion: 2,
      };
      expect(effectiveConsent(memberAllowed, baseSpace)).toBe("allowed");
    });

    it("returns withheld if charterVersion is stale", () => {
      const memberStale: SpaceMemberData = {
        uid: "user_1",
        role: "member",
        aiConsent: "allowed",
        consentCharterVersion: 1, // Space is version 2
      };
      expect(effectiveConsent(memberStale, baseSpace)).toBe("withheld");
    });

    it("returns withheld if aiConsent is pending or withheld", () => {
      const memberPending: SpaceMemberData = {
        uid: "user_1",
        role: "member",
        aiConsent: "pending",
        consentCharterVersion: 2,
      };
      const memberWithheld: SpaceMemberData = {
        uid: "user_2",
        role: "member",
        aiConsent: "withheld",
        consentCharterVersion: 2,
      };
      expect(effectiveConsent(memberPending, baseSpace)).toBe("withheld");
      expect(effectiveConsent(memberWithheld, baseSpace)).toBe("withheld");
    });

    it("returns withheld if member is null or undefined", () => {
      expect(effectiveConsent(null, baseSpace)).toBe("withheld");
      expect(effectiveConsent(undefined, baseSpace)).toBe("withheld");
    });
  });

  describe("OWN-MESSAGE EXCEPTION (Binding Requirement)", () => {
    it("allows requester to include their OWN messages even when their consent is withheld", () => {
      const ownMessageResult = canIncludeMessage({
        authorUid: "user_requester",
        requesterUid: "user_requester",
        authorEffectiveConsent: "withheld",
      });
      expect(ownMessageResult).toBe(true);

      const msg: MessageData = {
        id: "m_own",
        senderId: "user_requester",
        text: "I am proposing this idea.",
      };
      const member: SpaceMemberData = {
        uid: "user_requester",
        role: "member",
        aiConsent: "withheld",
        consentCharterVersion: 2,
      };

      const evalResult = evaluateMessageForHandoff({
        message: msg,
        authorMember: member,
        requesterUid: "user_requester",
        space: baseSpace,
      });

      expect(evalResult.canInclude).toBe(true);
      expect(evalResult.reason).toBe("included-own");
    });

    it("NEVER allows requester to include ANOTHER author's withheld messages, even if requester is admin", () => {
      const otherMessageResult = canIncludeMessage({
        authorUid: "user_other",
        requesterUid: "user_admin",
        authorEffectiveConsent: "withheld",
      });
      expect(otherMessageResult).toBe(false);

      const msg: MessageData = {
        id: "m_other",
        senderId: "user_other",
        text: "My secret project notes.",
      };
      const otherMember: SpaceMemberData = {
        uid: "user_other",
        role: "member",
        aiConsent: "withheld",
        consentCharterVersion: 2,
      };

      const evalResult = evaluateMessageForHandoff({
        message: msg,
        authorMember: otherMember,
        requesterUid: "user_admin",
        space: baseSpace,
      });

      expect(evalResult.canInclude).toBe(false);
      expect(evalResult.reason).toBe("excluded-withheld");
    });
  });

  describe("evaluateMessageForHandoff", () => {
    it("excludes deleted or tombstoned messages", () => {
      const msgDeleted: MessageData = {
        id: "m_del",
        senderId: "user_1",
        text: "",
        deletedAt: new Date(),
      };
      const member: SpaceMemberData = {
        uid: "user_1",
        role: "member",
        aiConsent: "allowed",
        consentCharterVersion: 2,
      };

      const evalResult = evaluateMessageForHandoff({
        message: msgDeleted,
        authorMember: member,
        requesterUid: "user_2",
        space: baseSpace,
      });

      expect(evalResult.canInclude).toBe(false);
      expect(evalResult.reason).toBe("excluded-deleted");
    });

    it("includes messages from consented authors with included-consented reason", () => {
      const msg: MessageData = {
        id: "m_consented",
        senderId: "user_1",
        text: "Let's use ultrasonic sensor HC-SR04.",
      };
      const member: SpaceMemberData = {
        uid: "user_1",
        role: "member",
        aiConsent: "allowed",
        consentCharterVersion: 2,
      };

      const evalResult = evaluateMessageForHandoff({
        message: msg,
        authorMember: member,
        requesterUid: "user_2",
        space: baseSpace,
      });

      expect(evalResult.canInclude).toBe(true);
      expect(evalResult.reason).toBe("included-consented");
    });
  });

  describe("policyPermitsHandoff", () => {
    it("enforces 'off' policy blocking all roles", () => {
      const offSpace: SpaceData = { ...baseSpace, aiPolicy: { handoff: "off" } };
      expect(policyPermitsHandoff(offSpace, "member")).toBe(false);
      expect(policyPermitsHandoff(offSpace, "admin")).toBe(false);
      expect(policyPermitsHandoff(offSpace, "owner")).toBe(false);
    });

    it("enforces 'admins' policy allowing only admin and owner", () => {
      const adminSpace: SpaceData = { ...baseSpace, aiPolicy: { handoff: "admins" } };
      expect(policyPermitsHandoff(adminSpace, "member")).toBe(false);
      expect(policyPermitsHandoff(adminSpace, "admin")).toBe(true);
      expect(policyPermitsHandoff(adminSpace, "owner")).toBe(true);
    });

    it("enforces 'anyone' policy allowing members", () => {
      const anyoneSpace: SpaceData = { ...baseSpace, aiPolicy: { handoff: "anyone" } };
      expect(policyPermitsHandoff(anyoneSpace, "member")).toBe(true);
    });
  });

  describe("isExpansion", () => {
    it("correctly identifies policy expansions and narrowings", () => {
      expect(isExpansion("off", "admins")).toBe(true);
      expect(isExpansion("admins", "anyone")).toBe(true);
      expect(isExpansion("off", "anyone")).toBe(true);
      expect(isExpansion("anyone", "admins")).toBe(false);
      expect(isExpansion("admins", "off")).toBe(false);
      expect(isExpansion("admins", "admins")).toBe(false);
    });
  });

  describe("redactContent", () => {
    it("redacts emails, phones, links, and long numbers", () => {
      const input = "Contact alex@example.com or visit https://agora.demo or call 555-123-4567 or ref 1234567890.";
      const redacted = redactContent(input);
      expect(redacted).not.toContain("alex@example.com");
      expect(redacted).toContain("[email]");
      expect(redacted).not.toContain("https://agora.demo");
      expect(redacted).toContain("[link]");
      expect(redacted).not.toContain("555-123-4567");
      expect(redacted).toContain("[phone]");
      expect(redacted).not.toContain("1234567890");
      expect(redacted).toContain("[number]");
    });
  });

  describe("computePayloadHash", () => {
    it("computes deterministic SHA-256 hash", () => {
      const payload = [{ token: "m1", authorLabel: "Member A", timestampIso: "2026-10-15T00:00:00Z", text: "Hello" }];
      const h1 = computePayloadHash(payload, 1, "anyone", "extract");
      const h2 = computePayloadHash(payload, 1, "anyone", "extract");
      const h3 = computePayloadHash(payload, 2, "anyone", "extract");
      expect(h1).toBe(h2);
      expect(h1).not.toBe(h3);
    });
  });
});
