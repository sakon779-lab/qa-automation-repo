import { defineConfig } from "@playwright/test";

/**
 * olympus-node-demo (Jira ONODE) — API suite. The app is an HTTP API, so specs use the `api`
 * fixture from resources/playwright/fixtures.ts; no browser is launched. Addresses are the QA
 * stack Hermes deploys (app :8006, Postgres :5442, MockServer :1087), each env-overridable —
 * the same role resources/projects/<service>/config.robot plays for a Robot project.
 *
 * QA_HOST moves all three at once: Jenkins runs in a container and reaches the stack as
 * host.docker.internal, the way the Robot job passes BASE_API_URL / DB_HOST.
 *
 * fullyParallel: every test runs alone and in any order (atomic tests), so a test that leans on
 * another's leftovers fails here instead of passing by luck.
 */
const host = process.env.QA_HOST ?? "localhost";

export default defineConfig<{ dbUrl: string; mockUrl: string }>({
  testDir: ".",
  testMatch: "**/*.spec.ts",
  fullyParallel: true,
  // One retry, in a fresh worker. Since the first browser-driven specs (ONODE-24/26, 6 Nov 2026) a
  // worker that has run a page test dies a few seconds later with "worker process exited
  // unexpectedly (code=3221226505)" — a native fast-fail (0xC0000409) on this Windows runner
  // (Node 24.15 + Playwright 1.64.1), landing on whichever API test that worker picked up next.
  // Measured: the API-only suite never crashes (140/140 ×1), the mixed suite crashes about every
  // other run at 8 workers, never at --workers=1, never with the browser spec alone. The retry
  // re-runs only the test the crash killed; a retried pass is reported as flaky and the KB keeps
  // that visible (tools/sync_test_results). A real assertion failure still fails twice.
  retries: 1,
  // list = what a person reads in the console · junit = Jenkins's test-results page (per-test
  // history, trend, re-run with one click) · json = what the KB ingests (TestRun /
  // TestCase.last_status — Artemis after every run, Jenkins after every build). results/ is
  // gitignored.
  reporter: [
    ["list"],
    ["junit", { outputFile: "../../results/playwright/node_demo-junit.xml" }],
    ["json", { outputFile: "../../results/playwright/node_demo.json" }],
  ],
  use: {
    baseURL: process.env.ONODE_QA_URL ?? `http://${host}:8006`,
    dbUrl: process.env.ONODE_QA_DB_URL ?? `postgresql://onode:onode@${host}:5442/onode`,
    mockUrl: process.env.ONODE_QA_MOCK_URL ?? `http://${host}:1087`,
  },
});
