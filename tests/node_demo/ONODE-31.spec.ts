import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-31 — ONODE-29 B9: the 409 txn_id collision must be a durable, distinguishable audit
 * signal. The preferred design (B9-B) is in effect: `PaymentOutcome` gains a fourth value
 * `MISMATCH`, and the audit row for a colliding gateway call is written with
 * `outcome = 'MISMATCH'` instead of `'SUCCESS'`. B9-C keeps exactly-once: one
 * `payment_attempts` row per gateway call on every path (201 / 200 / 409).
 *
 * One test per approved CSV row, titled with its CaseID. The gateway is stubbed through
 * `mock.arm` (scoped to this test's X-Request-Id, which `api` sends and the app forwards to the
 * external service), the DB is read back through `db`, and each test cleans up only its own rows
 * in a finally block so the fully-parallel suite never collides.
 *
 * TC-001 / TC-002 seed the pass through SQL (so the seeded pass writes NO audit row) and then
 * drive a colliding POST /passes: the single audit row left behind is the colliding gateway
 * call's, and it must read `MISMATCH` — not `SUCCESS`.
 */
test.describe("ONODE-31 — 409 txn_id collision is a durable, distinguishable audit signal", () => {
  // TC-001 — E12/B9/X1: SQL-seeded pass + colliding charge → 409, exactly one audit row, MISMATCH
  test("TC-001 a 409 txn_id collision on the findByTxnId path writes exactly one MISMATCH audit row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const txnId = `audit-txn-${dynamicId}`;
    const seededPlate = `AU${dynamicId}`.slice(0, 10);
    const requestPlate = `AV${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      // The SQL-seeded pass writes no payment_attempts row, so the colliding gateway call is the
      // only source of an audit row for this txn_id.
      await db.exec(
        `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) ` +
          `VALUES ('car', 1, '${seededPlate}', 100, '${txnId}', 'ACTIVE')`,
      );

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: requestPlate } });
      expect(res.status()).toBe(409);
      expect(await res.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      // The colliding call's audit row is distinguishable from a genuine purchase.
      expect(
        await db.value(`SELECT count(*) FROM payment_attempts WHERE txn_id = '${txnId}' AND outcome = 'MISMATCH'`),
      ).toBe(1);
      // Exactly one audit row total for this gateway call (B9-C: no double-write).
      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE txn_id = '${txnId}'`)).toBe(1);
      // No second passes row was written.
      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-002 — E12/B4/B9/X1: collision differing in vehicle/months (price differs) → same treatment
  test("TC-002 a 409 collision differing in vehicle and months writes outcome 'MISMATCH' and no new passes row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const txnId = `audit-txn-${dynamicId}`;
    const seededPlate = `AU${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      await db.exec(
        `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) ` +
          `VALUES ('car', 1, '${seededPlate}', 100, '${txnId}', 'ACTIVE')`,
      );

      const res = await api.post("/passes", { data: { vehicle: "motorcycle", months: 3, plate: seededPlate } });
      expect(res.status()).toBe(409);
      expect(await res.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(
        await db.value(`SELECT count(*) FROM payment_attempts WHERE txn_id = '${txnId}' AND outcome = 'MISMATCH'`),
      ).toBe(1);
      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-007 — E1: vehicle key absent → 400 'vehicle is required'
  test("TC-007 missing vehicle returns 400 'vehicle is required'", async ({ api, dynamicId }) => {
    const plate = `AU${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", { data: { months: 1, plate } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle is required" });
  });

  // TC-008 — E2: vehicle is a non-matching string → 400 'vehicle must be car or motorcycle'
  test("TC-008 vehicle 'truck' returns 400 'vehicle must be car or motorcycle'", async ({ api, dynamicId }) => {
    const plate = `AU${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", { data: { vehicle: "truck", months: 1, plate } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle must be car or motorcycle" });
  });

  // TC-009 — E3: months key absent → 400 'months is required'
  test("TC-009 missing months returns 400 'months is required'", async ({ api, dynamicId }) => {
    const plate = `AU${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", { data: { vehicle: "car", plate } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "months is required" });
  });

  // TC-010 — E4: months out of range (13) → 400 'months must be an integer from 1 to 12'
  test("TC-010 months 13 returns 400 'months must be an integer from 1 to 12'", async ({ api, dynamicId }) => {
    const plate = `AU${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", { data: { vehicle: "car", months: 13, plate } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "months must be an integer from 1 to 12" });
  });

  // TC-011 — E5: plate key absent → 400 'plate is required'
  test("TC-011 missing plate returns 400 'plate is required'", async ({ api }) => {
    const res = await api.post("/passes", { data: { vehicle: "car", months: 1 } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate is required" });
  });

  // TC-012 — E6: plate longer than 10 characters after trim → 400
  test("TC-012 over-long plate returns 400 'plate must be a string of at most 10 characters'", async ({ api }) => {
    const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: "ABCDEFGHIJK" } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate must be a string of at most 10 characters" });
  });

  // TC-013 — E7: gateway DECLINED → 402 'payment declined', no pass row
  test("TC-013 DECLINED charge returns 402 'payment declined' and writes no pass row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `AU${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "DECLINED" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(402);
      expect(await res.json()).toMatchObject({ detail: "payment declined" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // TC-014 — E8: gateway non-2xx (500) → 502 'payment gateway unavailable', no pass row
  test("TC-014 gateway HTTP 500 returns 502 'payment gateway unavailable' and writes no pass row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `AU${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 500, { error: "internal" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // TC-015 — E9: gateway SUCCESS with an empty txn_id → 502, no pass row
  test("TC-015 SUCCESS with an empty txn_id returns 502 'payment gateway unavailable' and writes no pass row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `AU${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // TC-016 — E10: gateway call times out → 502 'payment gateway unavailable', no pass row
  test("TC-016 gateway timeout returns 502 'payment gateway unavailable' and writes no pass row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `AU${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: `txn-${dynamicId}` }, { delayMs: 30000 });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });
});