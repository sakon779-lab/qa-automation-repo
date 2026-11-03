import { defineConfig } from "@playwright/test";

/**
 * olympus-node-demo (Jira ONODE) — API suite. The app is an HTTP API, so specs use the `api`
 * fixture from resources/playwright/fixtures.ts; no browser is launched. Addresses are the QA
 * stack Hermes deploys (app :8006, Postgres :5442, MockServer :1087), each env-overridable —
 * the same role resources/projects/<service>/config.robot plays for a Robot project.
 *
 * fullyParallel: every test runs alone and in any order (atomic tests), so a test that leans on
 * another's leftovers fails here instead of passing by luck.
 */
export default defineConfig<{ dbUrl: string; mockUrl: string }>({
  testDir: ".",
  testMatch: "**/*.spec.ts",
  fullyParallel: true,
  reporter: [["list"]],
  use: {
    baseURL: process.env.ONODE_QA_URL ?? "http://localhost:8006",
    dbUrl: process.env.ONODE_QA_DB_URL ?? "postgresql://onode:onode@127.0.0.1:5442/onode",
    mockUrl: process.env.ONODE_QA_MOCK_URL ?? "http://127.0.0.1:1087",
  },
});
