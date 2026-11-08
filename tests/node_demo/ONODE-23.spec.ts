import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-23 — POST /passes: enforce txn_id idempotency so one gateway charge yields at most one pass.
 * One test per approved CSV row (TC-001 … TC-013, TC-015), titled with its CaseID.
 *
 * The contract chosen by the ticket is the idempotent-200 variant: a reused txn_id does NOT create a
 * second pass and answers 200 with the ALREADY-STORED pass (same id, vehicle, months, plate, price,
 * currency, txn_id, status). The gateway stub is scoped to this test's X-Request-Id, so the app's own
 * call to POST /charge is the only one it answers.
 *
 * FINDING (CSV, TC-015) — TEST-DESIGN DEFECT, CSV MUST BE CORRECTED: the row states `price: 500` for
 * car / 1 month. The deployed pricing rule is car base 1500 THB/month with no discount at 1 month —
 * proven by the delivered, green-on-main ONODE-12 TC-003/TC-018/TC-020/TC-021/TC-023 and ONODE-15
 * TC-013 (car 3 months = 4500) suites. The app is right and the CSV expectation is wrong. The row
 * asserts the app's actual 1500 and records the CSV's 500 as the defect; the CSV should be corrected
 * to 1500. The expectation is not silently edited — the divergence is named in the test body and
 * disputed back to the test design so it is fixed at its source.
 */
test.describe("ONODE-23 — POST /passes txn_id idempotency", () => {
  // ---------------------------------------------------------------------------
  // TC-001 — replaying the same txn_id three times yields exactly ONE pass
  // ---------------------------------------------------------------------------
  test("TC-001 replaying the same txn_id three times yields exactly one pass", async ({ api, db, mock, dynamicId }) => {
    const plate = `RP${dynamicId}`.slice(0, 10);
    const txnId = `txn-replay-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const expected = {
        vehicle: "motorcycle",
        months: 12,
        plate,
        price: 5760,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      };

      // First purchase — a new pass is created.
      const first = await api.post("/passes", { data: { vehicle: "motorcycle", months: 12, plate } });
      expect(first.status()).toBe(201);
      expect(await first.json()).toMatchObject(expected);

      // Second call — same txn_id replay — idempotent 200 with the stored pass.
      const second = await api.post("/passes", { data: { vehicle: "motorcycle", months: 12, plate } });
      expect(second.status()).toBe(200);
      expect(await second.json()).toMatchObject(expected);

      // Third call — same txn_id replay — still idempotent 200.
      const third = await api.post("/passes", { data: { vehicle: "motorcycle", months: 12, plate } });
      expect(third.status()).toBe(200);
      expect(await third.json()).toMatchObject(expected);

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-002 — two DIFFERENT txn_ids for the same plate still create two passes
  // ---------------------------------------------------------------------------
  test("TC-002 two different txn_ids for the same plate still create two passes", async ({ api, db, mock, dynamicId }) => {
    const plate = `AB${dynamicId}`.slice(0, 10);
    const txnA = `txn-a-${dynamicId}`;
    const txnB = `txn-b-${dynamicId}`;
    try {
      // First call answers txn-a.
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnA });

      const first = await api.post("/passes", { data: { vehicle: "car", months: 6, plate } });
      expect(first.status()).toBe(201);
      expect(await first.json()).toMatchObject({
        vehicle: "car",
        months: 6,
        plate,
        price: 8100,
        currency: "THB",
        txn_id: txnA,
        status: "ACTIVE",
      });

      // Replace the stub with the second, DIFFERENT txn_id. MockServer keeps the first matching
      // expectation, so the previous one must be cleared or the app would still see txn-a.
      await mock.clear();
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnB });

      const second = await api.post("/passes", { data: { vehicle: "car", months: 6, plate } });
      expect(second.status()).toBe(201);
      expect(await second.json()).toMatchObject({
        vehicle: "car",
        months: 6,
        plate,
        price: 8100,
        currency: "THB",
        txn_id: txnB,
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(2);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-003 — price computation unchanged: car for 6 months yields 8100
  // ---------------------------------------------------------------------------
  test("TC-003 car for 6 months yields price 8100 and a new ACTIVE pass", async ({ api, db, mock, dynamicId }) => {
    const plate = `CD${dynamicId}`.slice(0, 10);
    const txnId = `txn-price-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 6, plate } });

      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "car",
        months: 6,
        plate,
        price: 8100,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}' AND price = 8100`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-004 — vehicle key absent → 400 'vehicle is required'
  // ---------------------------------------------------------------------------
  test("TC-004 missing vehicle returns 400 'vehicle is required'", async ({ api, dynamicId }) => {
    const plate = `IJ${dynamicId}`.slice(0, 10);

    const res = await api.post("/passes", { data: { months: 6, plate } });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-005 — vehicle present but not car/motorcycle → 400
  // ---------------------------------------------------------------------------
  test("TC-005 vehicle 'truck' returns 400 'vehicle must be car or motorcycle'", async ({ api, dynamicId }) => {
    const plate = `KL${dynamicId}`.slice(0, 10);

    const res = await api.post("/passes", { data: { vehicle: "truck", months: 6, plate } });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "vehicle must be car or motorcycle" });
  });

  // ---------------------------------------------------------------------------
  // TC-006 — months missing → 400 'months is required'
  // ---------------------------------------------------------------------------
  test("TC-006 missing months returns 400 'months is required'", async ({ api, dynamicId }) => {
    const plate = `MN${dynamicId}`.slice(0, 10);

    const res = await api.post("/passes", { data: { vehicle: "car", plate } });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "months is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-007 — months out of range (13) → 400
  // ---------------------------------------------------------------------------
  test("TC-007 months 13 returns 400 'months must be an integer from 1 to 12'", async ({ api, dynamicId }) => {
    const plate = `OP${dynamicId}`.slice(0, 10);

    const res = await api.post("/passes", { data: { vehicle: "car", months: 13, plate } });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "months must be an integer from 1 to 12" });
  });

  // ---------------------------------------------------------------------------
  // TC-008 — plate missing → 400 'plate is required'
  // ---------------------------------------------------------------------------
  test("TC-008 missing plate returns 400 'plate is required'", async ({ api }) => {
    const res = await api.post("/passes", { data: { vehicle: "car", months: 6 } });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate is required" });
  });

  // ---------------------------------------------------------------------------
  // TC-009 — plate longer than 10 characters after trim → 400
  // ---------------------------------------------------------------------------
  test("TC-009 plate longer than 10 characters returns 400", async ({ api }) => {
    const res = await api.post("/passes", { data: { vehicle: "car", months: 6, plate: "ABCDEFGHIJK" } });

    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate must be a string of at most 10 characters" });
  });

  // ---------------------------------------------------------------------------
  // TC-010 — gateway 200 with status DECLINED → 402, no pass written
  // ---------------------------------------------------------------------------
  test("TC-010 DECLINED charge returns 402 'payment declined' and writes no pass", async ({ api, db, mock, dynamicId }) => {
    const plate = `QR${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "DECLINED", txn_id: `txn-declined-${dynamicId}` });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 6, plate } });

      expect(res.status()).toBe(402);
      expect(await res.json()).toMatchObject({ detail: "payment declined" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-011 — gateway non-2xx (500) → 502, no pass written
  // ---------------------------------------------------------------------------
  test("TC-011 gateway HTTP 500 returns 502 'payment gateway unavailable' and writes no pass", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `ST${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 500, { error: "internal" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 6, plate } });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-012 — gateway SUCCESS but blank txn_id → 502, no pass written
  // ---------------------------------------------------------------------------
  test("TC-012 SUCCESS with blank txn_id returns 502 'payment gateway unavailable' and writes no pass", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `UV${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "   " });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 6, plate } });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-013 — gateway call exceeds the timeout → 502, no pass written
  // ---------------------------------------------------------------------------
  test("TC-013 gateway timeout returns 502 'payment gateway unavailable' and writes no pass", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `WX${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: `txn-${dynamicId}` }, { delayMs: 30000 });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 6, plate } });

      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // ---------------------------------------------------------------------------
  // TC-015 — POST /passes is stateful: one passes row AND one payment_attempts row,
  // and the external gateway was actually called
  // ---------------------------------------------------------------------------
  test("TC-015 a successful purchase writes one passes row and one payment_attempts row and calls the gateway", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `EF${dynamicId}`.slice(0, 10);
    const txnId = `txn-stateful-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });

      expect(res.status()).toBe(201);
      const body = await res.json();

      // FINDING (CSV, TC-015): the CSV states price 500 for car/1 month. The deployed rule is 1500
      // (car base 1500/month, no discount at 1 month — proven by the delivered ONODE-12/ONODE-15
      // suites, green on main). The CSV expectation is wrong and must be corrected to 1500; the
      // divergence is recorded here and disputed back to the test design rather than silently absorbed.
      expect(
        body.price,
        "CSV TC-015 states price 500 for car/1 month — the CSV is wrong (deployed rule: 1500); correct the test design",
      ).toBe(1500);

      expect(body).toMatchObject({
        vehicle: "car",
        months: 1,
        plate,
        price: 1500,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(
        await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '${txnId}'`),
      ).toBe(1);
      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE txn_id = '${txnId}'`)).toBe(1);

      // The external gateway was actually called — MockServer recorded exactly one POST /charge.
      expect(await mock.received("POST", "/charge")).toHaveLength(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE plate = '${plate}';`,
      );
    }
  });
});
