import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-60 — SEC-ONODE-29-3: the gateway txn_id is normalized to its canonical form (trimmed)
 * ONCE at the boundary, before it is used as an idempotency key, stored, echoed or audited.
 *
 * Every row of test_designs/ONODE-60.csv becomes one test. The gateway is stubbed through
 * `mock.arm` (scoped to this test's X-Request-Id, which `api` sends and the app forwards), the
 * DB is read back through `db`, and each test cleans up its own rows in a finally block so the
 * fully-parallel suite never collides.
 *
 * The two-call rows arm the stub twice: MockServer answers the FIRST matching request with the
 * first expectation and the second request with the second one (expectations are consumed in
 * order), so the whitespace-variant replay is exercised exactly as the finding describes.
 *
 * ONODE-64 retired TC-016 (the "database throws → 500" row): it proved a fault-only error by
 * renaming the shared `passes` table, which made every parallel test touching `passes` fail at
 * random. That obligation is proven at the unit layer by this card's own unit tests.
 *
 * AMENDED by ONODE-61 (TC-020): the seeded pass is looked up by its canonical txn_id regardless
 * of which JSON media type carried the body — application/*+json is now parsed too. The table is
 * shared and the suite is fully parallel, so the purity assertion is made on THIS test's own
 * suspicious entry and on the list's stability, never on the global `checked` count (another
 * test's insert between the two calls would move it — ONODE-16's "ห้ามเทียบจำนวนรวม" rule).
 */
test.describe("ONODE-60 — canonical (trimmed) gateway txn_id as the idempotency key", () => {
  // TC-001 — E1/B4/X2: 'txn-<id>' then ' txn-<id> ' with a DIFFERENT plate -> 409, one row
  test("TC-001 a whitespace-variant txn_id with a different plate answers 409 and writes one row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `W${dynamicId}`;
    const otherPlate = `V${dynamicId}`;
    const txnId = `txn-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const first = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(first.status()).toBe(201);
      expect(await first.json()).toMatchObject({
        vehicle: "car",
        months: 1,
        plate,
        price: 1500,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      // second call: same txn_id padded with a trailing space, DIFFERENT plate
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: ` ${txnId} ` });

      const second = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: otherPlate } });
      expect(second.status()).toBe(409);
      expect(await second.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${otherPlate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}'`,
      );
    }
  });

  // TC-002 — B4/B5: whitespace-variant txn_id with the SAME four fields → idempotent 200, one row
  test("TC-002 a whitespace-variant txn_id with the same four fields answers 200 and writes one row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `W${dynamicId}`;
    const txnId = `txn-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const first = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(first.status()).toBe(201);
      expect(await first.json()).toMatchObject({
        vehicle: "car",
        months: 1,
        plate,
        price: 1500,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      // second call: same txn_id padded with whitespace, identical four fields
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: ` ${txnId} ` });

      const second = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(second.status()).toBe(200);
      expect(await second.json()).toMatchObject({
        vehicle: "car",
        months: 1,
        plate,
        price: 1500,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}'`,
      );
    }
  });

  // TC-003 — E2: whitespace-only txn_id → 502, no row
  test("TC-003 a whitespace-only txn_id answers 502 and writes no row", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "   " });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-004 — E3: vehicle key absent → 400, no row
  test("TC-004 returns 400 when the vehicle key is absent", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      const res = await api.post("/passes", { data: { months: 1, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "vehicle is required" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-005 — E4: vehicle is a non-string JSON value (number 1) → 400, no row
  test("TC-005 returns 400 when vehicle is a non-string value", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      const res = await api.post("/passes", { data: { vehicle: 1, months: 1, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "vehicle must be car or motorcycle" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-006 — E5: months key absent → 400, no row
  test("TC-006 returns 400 when the months key is absent", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "months is required" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-007 — E6: months out of range (13) → 400, no row
  test("TC-007 returns 400 when months is out of range", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", months: 13, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "months must be an integer from 1 to 12" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-008 — E7: whitespace-only plate → 400
  test("TC-008 returns 400 when the plate is whitespace-only", async ({ api }) => {
    const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: "   " } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate is required" });
  });

  // TC-009 — E8: trimmed plate longer than 10 characters → 400
  test("TC-009 returns 400 when the trimmed plate is longer than 10 characters", async ({ api }) => {
    const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: "ABCDEFGHIJK" } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate must be a string of at most 10 characters" });
  });
});

test.describe("ONODE-60 — gateway outcomes, framework guards and DB backstops", () => {
  // TC-010 — E9: gateway DECLINED → 402, no row
  test("TC-010 returns 402 when the gateway declines the charge", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn-declined-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "DECLINED", txn_id: txnId });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(402);
      expect(await res.json()).toMatchObject({ detail: "payment declined" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-011 — E10: gateway answers non-2xx → 502, no row
  test("TC-011 returns 502 when the gateway answers HTTP 500", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 500, { error: "internal" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-012 — E11: the gateway call exceeds PAYMENT_GATEWAY_TIMEOUT_MS → 502, no row
  test("TC-012 returns 502 when the gateway call times out", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: `txn-${dynamicId}` }, { delayMs: 30000 });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-013 — E14: a body that is not valid JSON → 400 'request body must be valid JSON'
  test("TC-013 returns 400 when the request body is not valid JSON", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": "application/json" },
      data: Buffer.from("{not valid json"),
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "request body must be valid JSON" });
  });

  // TC-014 — E15: Content-Type application/xml → 415 'unsupported content type'
  test("TC-014 returns 415 for an unsupported content type", async ({ api }) => {
    const res = await api.post("/passes", {
      headers: { "Content-Type": "application/xml" },
      data: Buffer.from("<passes><vehicle>car</vehicle></passes>"),
    });
    expect(res.status()).toBe(415);
    expect(await res.json()).toMatchObject({ detail: "unsupported content type" });
  });

  // TC-015 — E16: a body larger than the 1048576-byte limit → 413
  test("TC-015 returns 413 when the request body is too large", async ({ api }) => {
    const padded = "A".repeat(1_100_000);
    const res = await api.post("/passes", {
      headers: { "Content-Type": "application/json" },
      data: Buffer.from(JSON.stringify({ vehicle: "car", months: 1, plate: padded })),
    });
    expect(res.status()).toBe(413);
    expect(await res.json()).toMatchObject({ detail: "request body too large" });
  });

  // TC-017 — E19: a wrong reconciliation token → 401 and discloses nothing
  test("TC-017 a wrong reconciliation token answers 401 and discloses nothing", async ({ api, dynamicId }) => {
    const res = await api.get("/passes/reconciliation", {
      headers: { "X-Reconciliation-Token": `wrong-token-${dynamicId}` },
    });
    expect(res.status()).toBe(401);
    const body = await res.json();
    expect(body).toMatchObject({ detail: "unauthorized" });
    expect(body).not.toHaveProperty("checked");
    expect(body).not.toHaveProperty("suspicious");
  });

  // TC-018 — B6: the passes_txn_id_unique constraint refuses a duplicate canonical txn_id
  test("TC-018 the passes_txn_id_unique constraint refuses a duplicate canonical txn_id", async ({ db, dynamicId }) => {
    const txnId = `txn-uniq-${dynamicId}`;
    try {
      await db.exec(
        `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, 'U${dynamicId}', 1500, '${txnId}', 'ACTIVE')`,
      );

      await expect(
        db.exec(
          `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, 'X${dynamicId}', 1500, '${txnId}', 'ACTIVE')`,
        ),
      ).rejects.toThrow(/passes_txn_id_unique/);

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE txn_id = '${txnId}'`);
    }
  });

  // TC-019 — B12: a successful purchase writes one passes row AND one payment_attempts row,
  // and the external gateway was actually called once
  test("TC-019 a successful purchase writes one passes row and one audit row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `S${dynamicId}`;
    const txnId = `txn-stateful-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "car",
        months: 1,
        plate,
        price: 1500,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(
        await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}' AND status = 'ACTIVE'`),
      ).toBe(1);
      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE txn_id = '${txnId}'`)).toBe(1);
      expect(await mock.received("POST", "/charge")).toHaveLength(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}'`,
      );
    }
  });

  // TC-020 — B13: reconcile() is a pure function of its two list arguments — two consecutive
  // calls with no DB change return the same suspicious list, and the seeded pass is still listed
  // with the same reason. AMENDED by ONODE-61: the seeded pass is looked up by its canonical
  // txn_id regardless of which JSON media type carried the body (application/*+json is now
  // parsed too). The table is shared and the suite is fully parallel, so the global `checked`
  // count is NOT compared across the two calls (another test's insert would move it); purity is
  // asserted on THIS test's own entry and on the stability of the list it appears in.
  test("TC-020 reconciliation is pure across two consecutive calls", async ({ api, db, dynamicId }) => {
    const plate = `R${dynamicId}`;
    const txnId = `txn-pure-${dynamicId}`;
    try {
      await db.exec(
        `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, '${plate}', 1500, '${txnId}', 'ACTIVE')`,
      );

      const first = await api.get("/passes/reconciliation", {
        headers: { "X-Reconciliation-Token": "qa-reconciliation-token" },
      });
      expect(first.status()).toBe(200);
      const firstBody = await first.json();
      expect(typeof firstBody.checked).toBe("number");
      expect(Array.isArray(firstBody.suspicious)).toBe(true);
      expect(firstBody.suspicious).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ plate, reason: "no successful payment attempt" }),
        ]),
      );

      const second = await api.get("/passes/reconciliation", {
        headers: { "X-Reconciliation-Token": "qa-reconciliation-token" },
      });
      expect(second.status()).toBe(200);
      const secondBody = await second.json();
      expect(typeof secondBody.checked).toBe("number");
      expect(Array.isArray(secondBody.suspicious)).toBe(true);

      // Purity: THIS test's own entry is identical in both calls (same plate, same reason).
      const ownFirst = (firstBody.suspicious as Array<Record<string, unknown>>).filter((s) => s.plate === plate);
      const ownSecond = (secondBody.suspicious as Array<Record<string, unknown>>).filter((s) => s.plate === plate);
      expect(ownFirst).toHaveLength(1);
      expect(ownSecond).toEqual(ownFirst);

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE txn_id = '${txnId}'`);
    }
  });

  // TC-021 — B7: the per-client rate limit is unchanged — a normal request succeeds with 201
  test("TC-021 a normal request under the rate limit succeeds with 201", async ({ api, db, mock, dynamicId }) => {
    const plate = `Q${dynamicId}`;
    const txnId = `txn-rate-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).not.toBe(429);
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "car",
        months: 1,
        plate,
        price: 1500,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}'`,
      );
    }
  });

  // TC-022 — E1/B4: the four-field binding fires on the CANONICAL key — a 409 writes exactly one
  // payment_attempts MISMATCH row carrying the canonical txn_id and no second passes row
  test("TC-022 the four-field binding fires on the canonical key and audits one MISMATCH row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `W${dynamicId}`;
    const otherPlate = `V${dynamicId}`;
    const txnId = `txn-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const first = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(first.status()).toBe(201);
      expect(await first.json()).toMatchObject({
        vehicle: "car",
        months: 1,
        plate,
        price: 1500,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: ` ${txnId} ` });

      const second = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: otherPlate } });
      expect(second.status()).toBe(409);
      expect(await second.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${otherPlate}'`)).toBe(0);
      expect(
        await db.value(
          `SELECT count(*) FROM payment_attempts WHERE txn_id = '${txnId}' AND outcome = 'MISMATCH'`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}'`,
      );
    }
  });
});
