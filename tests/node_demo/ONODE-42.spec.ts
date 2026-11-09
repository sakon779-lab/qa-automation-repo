import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-42 — GET /passes/reconciliation is now behind a shared-secret boundary (B1).
 *
 * The endpoint requires the `X-Reconciliation-Token` header equal to RECONCILIATION_TOKEN
 * (constant-time compare). A missing or wrong token answers 401 `unauthorized` and the body
 * discloses NOTHING — no `checked` count, no `suspicious` list (SEC-ONODE-16-1 replay must
 * report CLOSED). An authorized caller gets the UNCHANGED ONODE-16 body shape:
 * `{ checked: <number>, suspicious: <list> }`.
 *
 * One test per approved CSV row (test_designs/ONODE-42.csv): TC-001, TC-002, TC-003.
 * The token value is the one the CSV prescribes for the QA stack.
 */
const RECONCILIATION_TOKEN = "qa-reconciliation-token";

test.describe("ONODE-42 — reconciliation endpoint requires the shared-secret token", () => {
  // ---------------------------------------------------------------------------
  // TC-001 — no X-Reconciliation-Token header → 401 'unauthorized', no disclosure
  // ---------------------------------------------------------------------------
  test("TC-001 reconciliation without the X-Reconciliation-Token header returns 401 and discloses nothing", async ({
    api,
  }) => {
    const res = await api.get("/passes/reconciliation");

    expect(res.status()).toBe(401);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body).toMatchObject({ detail: "unauthorized" });
    expect(body).not.toHaveProperty("checked");
    expect(body).not.toHaveProperty("suspicious");
  });

  // ---------------------------------------------------------------------------
  // TC-002 — wrong X-Reconciliation-Token → 401 'unauthorized', no disclosure
  // ---------------------------------------------------------------------------
  test("TC-002 reconciliation with a wrong X-Reconciliation-Token returns 401 and discloses nothing", async ({
    api,
    dynamicId,
  }) => {
    const res = await api.get("/passes/reconciliation", {
      headers: { "X-Reconciliation-Token": `wrong-token-${dynamicId}` },
    });

    expect(res.status()).toBe(401);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body).toMatchObject({ detail: "unauthorized" });
    expect(body).not.toHaveProperty("checked");
    expect(body).not.toHaveProperty("suspicious");
  });

  // ---------------------------------------------------------------------------
  // TC-003 — correct X-Reconciliation-Token → 200 with the unchanged ONODE-16 body shape
  // ---------------------------------------------------------------------------
  test("TC-003 reconciliation with the correct X-Reconciliation-Token returns 200 with the unchanged body shape", async ({
    api,
  }) => {
    const res = await api.get("/passes/reconciliation", {
      headers: { "X-Reconciliation-Token": RECONCILIATION_TOKEN },
    });

    expect(res.status()).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    expect(typeof body.checked).toBe("number");
    expect(Array.isArray(body.suspicious)).toBe(true);
  });
});
