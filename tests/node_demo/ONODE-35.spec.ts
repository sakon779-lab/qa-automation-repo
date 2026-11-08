import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-35 — GET /passes/{id} id validation on the by-id read path (SEC-ONODE-32-2 follow-up).
 *
 * One test per approved CSV row (TC-003, TC-004, TC-005), titled with its CaseID. Every row is a
 * negative row: the id path segment is not a positive in-range integer, or no passes row exists,
 * and the endpoint must answer 404 'pass not found' — never a 500 and never a leaked DB error.
 * No row seeds state, so no row needs a teardown.
 *
 * The by-id read now passes through the source-IP per-client limiter and the process-wide global
 * ceiling (ONODE-35 B6 amendment); the app is built with an injected per-client limiter (max 30)
 * and global limiter (max 300) on a fixed clock, so these three single reads are not refused by a
 * shared process-wide bucket and the 404 body is unchanged.
 */
test.describe("ONODE-35 — GET /passes/{id} id validation", () => {
  test("TC-003 non-numeric id 'not-a-number' → 404 'pass not found'", async ({ api }) => {
    const res = await api.get("/passes/not-a-number");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-004 id one past Postgres integer max '2147483648' → 404 'pass not found'", async ({ api }) => {
    const res = await api.get("/passes/2147483648");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-005 valid in-range integer with no passes row → 404 'pass not found'", async ({ api, dynamicId }) => {
    // A positive integer id that cannot exist: derived from the unique dynamicId, far above any
    // row this suite creates, and never inserted by this test.
    const missingId = 1_000_000_000 + dynamicId;
    const res = await api.get(`/passes/${missingId}`);
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });
});
