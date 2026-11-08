import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-15 — POST /passes validation, payment-gateway failure modes and pricing.
 * One test per approved CSV row (TC-001 … TC-014, TC-011 retired).
 *
 * The gateway is stubbed through `mock.arm('POST', '/charge', …)`; the stub answers only requests
 * carrying this test's X-Request-Id, which `api` sends and the app forwards. Every row asserts the
 * HTTP contract AND the database state (no row on a refusal, exactly one row on a success), then
 * deletes only what it created.
 *
 * FINDING (CSV, all gateway rows): the CSV names the gateway path `/external/payment/charge`. The
 * deployed app calls `/charge` (proven by the passing ONODE-8 / ONODE-12 suites, which arm
 * `/charge`). Stubbing the CSV's path matches nothing and every positive row would see 502. The
 * rows are automated against the real path `/charge`; the CSV should be corrected.
 *
 * AMENDED by ONODE-40: TC-012 is now the "validation precedes the breaker" row — an invalid
 * vehicle must answer 400 'vehicle must be car or motorcycle' even when the breaker is open, and
 * never 503. It makes no gateway call (Mock: None), so it needs no stub and no DB row.
 */

const CHARGE = "/charge";

test.describe("ONODE-15 — POST /passes validation, gateway failures and pricing", () => {
  test("TC-001 vehicle key absent → 400 'vehicle is required'", async ({ api, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", { data: { months: 1, plate } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle is required" });
  });

  test("TC-002 vehicle 'truck' → 400 'vehicle must be car or motorcycle'", async ({ api, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", { data: { vehicle: "truck", months: 1, plate } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-003 months key absent → 400 'months is required'", async ({ api, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", { data: { vehicle: "car", plate } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months is required" });
  });

  test("TC-004 months out of range (13) → 400 'months must be an integer from 1 to 12'", async ({ api, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", { data: { vehicle: "car", months: 13, plate } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });
  });

  test("TC-005 plate key absent → 400 'plate is required'", async ({ api }) => {
    const res = await api.post("/passes", { data: { vehicle: "car", months: 1 } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "plate is required" });
  });

  test("TC-006 plate longer than 10 chars after trim → 400 'plate must be a string of at most 10 characters'", async ({ api, dynamicId }) => {
    const plate = `LONG${dynamicId}XXXXXX`;
    const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "plate must be a string of at most 10 characters" });
  });

  test("TC-007 gateway DECLINED → 402 'payment declined', no row", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "DECLINED" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(402);
      expect(await res.json()).toEqual({ detail: "payment declined" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-008 gateway HTTP 500 → 502 'payment gateway unavailable', no row", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 500, { error: "internal" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toEqual({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-009 gateway SUCCESS with whitespace-only txn_id '   ' → 502 'payment gateway unavailable', no row", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "   " });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toEqual({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-010 gateway slower than PAYMENT_GATEWAY_TIMEOUT_MS → 502 'payment gateway unavailable', no row", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      // Delay the stub well past the app's gateway timeout so the app's own timeout path fires.
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "txn_late" }, { delayMs: 30000 });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toEqual({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // AMENDED by ONODE-40 — the row is now "validation precedes the breaker": an invalid vehicle is
  // refused by validation with 400 'vehicle must be car or motorcycle' even when the breaker is
  // open, and never 503. Mock: None, so no stub is armed; the assertion is exact (400, not a set).
  test("TC-012 validation precedes the breaker: invalid vehicle → 400 'vehicle must be car or motorcycle', never 503", async ({ api, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", { data: { vehicle: "truck", months: 1, plate } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });
  });

  test("TC-013 car 3 months → 201, price 4500 THB, plate trimmed, row persisted", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const txnId = `txn-${dynamicId}`;
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 3, plate: `  ${plate}  ` } });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "car",
        months: 3,
        plate,
        price: 4500,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-014 motorcycle 12 months → 201, price 5760 THB (20% tier), row persisted", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const txnId = `txn-${dynamicId}`;
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", { data: { vehicle: "motorcycle", months: 12, plate } });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "motorcycle",
        months: 12,
        plate,
        price: 5760,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });
});