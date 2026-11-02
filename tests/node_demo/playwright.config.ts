import { defineConfig } from "@playwright/test";

/**
 * olympus-node-demo (Jira ONODE) — API suite. The app is an HTTP API, so specs use Playwright's
 * `request` fixture; no browser is launched. The base URL is the QA stack Hermes deploys.
 */
export default defineConfig({
  testDir: ".",
  testMatch: "**/*.spec.ts",
  reporter: [["list"]],
  use: {
    baseURL: process.env.ONODE_QA_URL ?? "http://localhost:8006",
  },
});
