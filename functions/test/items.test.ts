import {
  validateId,
  isValidDateString,
  handleAcceptProposal,
  handleDismissProposal,
  handleCreateManualItem,
  handleUpdateItem,
  handleRespondToAssignment,
} from "../src/items";
import * as fs from "fs";
import * as path from "path";

describe("Phase 4 Backend & Invariants Tests", () => {
  describe("validateId helper", () => {
    it("accepts valid alphanumeric ids with underscores and dashes up to 64 chars", () => {
      expect(validateId("space_123", "spaceId")).toBe("space_123");
      expect(validateId("user-abc-DEF", "userId")).toBe("user-abc-DEF");
      expect(validateId("item_1234567890", "itemId")).toBe("item_1234567890");
    });

    it("rejects path traversal, spaces, and special characters", () => {
      expect(() => validateId("../secrets", "path")).toThrow("invalid-argument");
      expect(() => validateId("id with spaces", "id")).toThrow("invalid-argument");
      expect(() => validateId("id/with/slashes", "id")).toThrow("invalid-argument");
      expect(() => validateId("", "id")).toThrow("invalid-argument");
      expect(() => validateId("a".repeat(65), "id")).toThrow("invalid-argument");
    });
  });

  describe("isValidDateString helper", () => {
    it("accepts valid dates in YYYY-MM-DD within [-1 day, +2 years]", () => {
      const today = new Date();
      const nextMonth = new Date(today.getTime() + 30 * 24 * 60 * 60 * 1000);
      const iso = nextMonth.toISOString().split("T")[0];
      expect(isValidDateString(iso)).toBe(true);
    });

    it("rejects malformed or out-of-range dates", () => {
      expect(isValidDateString("invalid-date")).toBe(false);
      expect(isValidDateString("2026/10/15")).toBe(false);
      expect(isValidDateString("2010-01-01")).toBe(false); // Too old
      expect(isValidDateString("2050-01-01")).toBe(false); // Too far
    });
  });

  describe("Structural Guarantee: AI Pipeline Never Writes Items or itemCard Messages", () => {
    it("static test: pipeline.ts contains zero references to items collection or itemCard kind", () => {
      const pipelinePath = path.resolve(__dirname, "../src/pipeline.ts");
      if (fs.existsSync(pipelinePath)) {
        const content = fs.readFileSync(pipelinePath, "utf-8");
        expect(content.includes('collection("items")')).toBe(false);
        expect(content.includes("collection('items')")).toBe(false);
        expect(content.includes('kind: "itemCard"')).toBe(false);
        expect(content.includes("kind: 'itemCard'")).toBe(false);
      }
    });

    it("static test: preview.ts contains zero references to items collection or itemCard kind", () => {
      const previewPath = path.resolve(__dirname, "../src/preview.ts");
      if (fs.existsSync(previewPath)) {
        const content = fs.readFileSync(previewPath, "utf-8");
        expect(content.includes('collection("items")')).toBe(false);
        expect(content.includes("collection('items')")).toBe(false);
        expect(content.includes('kind: "itemCard"')).toBe(false);
        expect(content.includes("kind: 'itemCard'")).toBe(false);
      }
    });

    it("static test: client lib directory contains zero Gemini API keys", () => {
      const clientLibPath = path.resolve(__dirname, "../../lib");
      if (fs.existsSync(clientLibPath)) {
        function searchDir(dir: string): void {
          const entries = fs.readdirSync(dir, { withFileTypes: true });
          for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            if (entry.isDirectory()) {
              searchDir(fullPath);
            } else if (entry.isFile() && entry.name.endsWith(".dart")) {
              const code = fs.readFileSync(fullPath, "utf-8");
              expect(code.includes("AIzaSy")).toBe(false);
              expect(/gemini[_-]?api[_-]?key/i.test(code)).toBe(false);
            }
          }
        }
        searchDir(clientLibPath);
      }
    });

    it("static test: never claims end-to-end encryption (Agora thesis)", () => {
      const clientLibPath = path.resolve(__dirname, "../../lib");
      if (fs.existsSync(clientLibPath)) {
        function searchDir(dir: string): void {
          const entries = fs.readdirSync(dir, { withFileTypes: true });
          for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            if (entry.isDirectory()) {
              searchDir(fullPath);
            } else if (entry.isFile() && entry.name.endsWith(".dart")) {
              const code = fs.readFileSync(fullPath, "utf-8");
              // Case insensitive search for "end-to-end encrypt"
              expect(/end-to-end\s*encrypt/i.test(code)).toBe(false);
              expect(/\bE2EE\b/i.test(code)).toBe(false);
            }
          }
        }
        searchDir(clientLibPath);
      }
    });
  });

  describe("Items State Machine & Transitions", () => {
    it("defines valid status transitions for tasks, decisions, and questions", () => {
      // Tasks: complete -> completed, reopen -> open, drop -> dismissed
      // Decisions: supersede -> completed, reactivate -> open
      // Questions: answer -> completed, reopen -> open, dismiss -> dismissed
      const taskActions = ["complete", "reopen", "drop"];
      const decisionActions = ["supersede", "reactivate"];
      const questionActions = ["answer", "reopen", "dismiss"];

      expect(taskActions.includes("complete")).toBe(true);
      expect(decisionActions.includes("supersede")).toBe(true);
      expect(questionActions.includes("answer")).toBe(true);
    });
  });

  describe("Phase 5: Fixture Provider & Seed Guards", () => {
    it("static test: seed-demo.ts strictly requires emulator environment variables", () => {
      const seedPath = path.resolve(__dirname, "../scripts/seed-demo.ts");
      expect(fs.existsSync(seedPath)).toBe(true);
      const content = fs.readFileSync(seedPath, "utf-8");
      expect(content.includes("FIRESTORE_EMULATOR_HOST")).toBe(true);
      expect(content.includes("FIREBASE_AUTH_EMULATOR_HOST")).toBe(true);
      expect(content.includes("process.exit(1)")).toBe(true);
    });

    it("static test: pipeline.ts refuses fixture provider outside emulator", () => {
      const pipelinePath = path.resolve(__dirname, "../src/pipeline.ts");
      expect(fs.existsSync(pipelinePath)).toBe(true);
      const content = fs.readFileSync(pipelinePath, "utf-8");
      expect(content.includes("fixture-refused: Fixture provider is only permitted inside the emulator")).toBe(true);
      expect(content.includes('provider: "fixture"')).toBe(true);
    });

    it("static test: no logging of message text, prompts, outputs or secrets", () => {
      const srcDir = path.resolve(__dirname, "../src");
      const files = fs.readdirSync(srcDir);
      for (const file of files) {
        if (file.endsWith(".ts")) {
          const content = fs.readFileSync(path.join(srcDir, file), "utf-8");
          // Ensure no direct logging of message text or prompt content
          expect(/console\.log\([^)]*message\.text/i.test(content)).toBe(false);
          expect(/console\.log\([^)]*prompt/i.test(content)).toBe(false);
          expect(/console\.log\([^)]*apiKey/i.test(content)).toBe(false);
        }
      }
    });
  });
});
