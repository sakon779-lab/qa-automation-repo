import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-29 — POST /passes txn_id binding (SEC-ONODE-23-1): a reused gateway txn_id is only
 * idempotent when the request matches the stored pass on all four fields (vehicle, months,
 * plate, price). Any mismatch answers 409 'txn_id already used for a different purchase' and
 * writes no new passes row. Reconciliation masks suspicious[].txn_id as '****' + the LAST 2
 * characters of the stored value (B15).
 *
 * One test per approved CSV row, titled with its CaseID. The gateway is stubbed through
 * `mock.arm` (scoped to this test's X-Request-Id, which `api` sends and the app forwards), the
 * DB is read back through `db`, and each test cleans up only its own rows in a finally block so
 * the fully-parallel suite never collides.
 *
 * AMENDED by ONODE-40: the CSV's TC-007 (the old 'duplicate txn_id' seed row) and TC-021 / TC-023
 * (circuit breaker 503, rate limiter 429) were RETIRED — those rows no longer exist in the
 * approved design, so their tests are removed and the suite matches the CSV one-to-one.
 *
 * FINDING (CSV, TC-028): the row seeds TWO passes with the SAME txn_id to exercise the
 * reconciliation 'duplicate txn_id' branch. The deployed schema's `passes_txn_id_unique`
 * constraint forbids that state (the second INSERT is refused — observed in the run). The branch
 * is therefore unreachable through the schema from a robot. The row is automated to prove
 * exactly that: the CSV's seed is refused BY NAME by the constraint, and reconciliation still
 * answers 200 with its contract keys. The CSV should be corrected (drop the row or relax the
 * constraint) — the expectation is not edited to match the app.
 */
test.describe("ONODE-29 — txn_id binding on POST /passes and reconciliation masking", () => {
  // TC-001 — B3: replaying the SAME txn_id with an identical request returns 200, one row
  test("TC-001 replaying the same txn_id with an identical request returns 200 and writes no second row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `V${dynamicId}`.slice(0, 10);
    const txnId = `txn-same-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const expected = {
        vehicle: "car",
        months: 6,
        plate,
        price: 8100,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      };

      const first = await api.post("/passes", { data: { vehicle: "car", months: 6, plate } });
      expect(first.status()).toBe(201);
      expect(await first.json()).toMatchObject(expected);

      const second = await api.post("/passes", { data: { vehicle: "car", months: 6, plate } });
      expect(second.status()).toBe(200);
      expect(await second.json()).toMatchObject(expected);

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-002 — B4: reused txn_id with a DIFFERENT plate → 409, no new row
  test("TC-002 a reused txn_id with a different plate returns 409 and writes no new row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `V${dynamicId}`.slice(0, 10);
    const otherPlate = `A${dynamicId}`.slice(0, 10);
    const txnId = `txn-plate-${dynamicId}`;
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

      const second = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: otherPlate } });
      expect(second.status()).toBe(409);
      expect(await second.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-003 — B4/B5: reused txn_id with a DIFFERENT vehicle (different price) → 409
  test("TC-003 a reused txn_id with a different vehicle returns 409 and writes no new row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `V${dynamicId}`.slice(0, 10);
    const otherPlate = `A${dynamicId}`.slice(0, 10);
    const txnId = `txn-veh-${dynamicId}`;
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

      const second = await api.post("/passes", {
        data: { vehicle: "motorcycle", months: 12, plate: otherPlate },
      });
      expect(second.status()).toBe(409);
      expect(await second.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-004 — B4: reused txn_id with a DIFFERENT months value → 409
  test("TC-004 a reused txn_id with a different months value returns 409 and writes no new row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `V${dynamicId}`.slice(0, 10);
    const txnId = `txn-mon-${dynamicId}`;
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

      const second = await api.post("/passes", { data: { vehicle: "car", months: 12, plate } });
      expect(second.status()).toBe(409);
      expect(await second.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-005 — B2: plate differing only by surrounding whitespace → 200 with the stored pass
  test("TC-005 a reused txn_id whose plate differs only by surrounding whitespace returns 200", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `V${dynamicId}`.slice(0, 10);
    const txnId = `txn-trim-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const expected = {
        vehicle: "car",
        months: 1,
        plate,
        price: 1500,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      };

      const first = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(first.status()).toBe(201);
      expect(await first.json()).toMatchObject(expected);

      const second = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: `  ${plate}  ` } });
      expect(second.status()).toBe(200);
      expect(await second.json()).toMatchObject(expected);

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-006 — B4: plate differing only by CASE → 409 (comparison is case-sensitive)
  test("TC-006 a reused txn_id whose plate differs only by case returns 409", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `V${dynamicId}`.slice(0, 10);
    const lowerPlate = `v${dynamicId}`.slice(0, 10);
    const txnId = `txn-case-${dynamicId}`;
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

      const second = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: lowerPlate } });
      expect(second.status()).toBe(409);
      expect(await second.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-008 — B1: POST /passes stays stateful — one passes row, one audit row, gateway called
  test("TC-008 a successful purchase writes one passes row and one payment_attempts row and calls the gateway", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `S${dynamicId}`.slice(0, 10);
    const txnId = `txn-stateful-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

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

      expect(
        await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}' AND status = 'ACTIVE'`),
      ).toBe(1);
      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE txn_id = '${txnId}'`)).toBe(1);
      expect(await mock.received("POST", "/charge")).toHaveLength(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });
});
// TC-009 — B1: a genuinely NEW txn_id still returns 201 with the new pass
  test("TC-009 a genuinely new txn_id returns 201 with the new pass", async ({ api, db, mock, dynamicId }) => {
    const plate = `N${dynamicId}`.slice(0, 10);
    const txnId = `txn-new-${dynamicId}`;
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

      expect(
        await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}' AND status = 'ACTIVE'`),
      ).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-010 — B6: two CONCURRENT POSTs with the same txn_id, different plates →
  // exactly one 201 and exactly one 409 (order-independent), exactly one row
  test("TC-010 two concurrent requests with the same txn_id yield exactly one 201 and one 409", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plateR = `R${dynamicId}`.slice(0, 10);
    const plateT = `T${dynamicId}`.slice(0, 10);
    const txnId = `txn-race-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const [resA, resB] = await Promise.all([
        api.post("/passes", { data: { vehicle: "car", months: 1, plate: plateR } }),
        api.post("/passes", { data: { vehicle: "car", months: 1, plate: plateT } }),
      ]);

      const statuses = [resA.status(), resB.status()].sort((a, b) => a - b);
      expect(statuses).toEqual([201, 409]);

      const conflict = resA.status() === 409 ? resA : resB;
      expect(await conflict.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-011 — E1: vehicle key absent → 400 'vehicle is required', no row
  test("TC-011 missing vehicle returns 400 'vehicle is required' and writes no row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", { data: { months: 1, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "vehicle is required" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // TC-012 — E2: vehicle is a non-string JSON value (number 1) → 400, no row
  test("TC-012 non-string vehicle returns 400 'vehicle must be car or motorcycle' and writes no row", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", { data: { vehicle: 1, months: 1, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "vehicle must be car or motorcycle" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // TC-013 — E3: months key absent → 400 'months is required', no row
  test("TC-013 missing months returns 400 'months is required' and writes no row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "months is required" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // TC-014 — E4: months out of range (13) → 400, no row
  test("TC-014 months 13 returns 400 'months must be an integer from 1 to 12' and writes no row", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", months: 13, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "months must be an integer from 1 to 12" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // TC-015 — E5: whitespace-only plate → 400 'plate is required' (no post-assertions/teardown)
  test("TC-015 whitespace-only plate returns 400 'plate is required'", async ({ api }) => {
    const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: "   " } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate is required" });
  });

  // TC-016 — E6: trimmed plate longer than 10 characters → 400 (no post-assertions/teardown)
  test("TC-016 over-long plate returns 400 'plate must be a string of at most 10 characters'", async ({ api }) => {
    const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: "ABCDEFGHIJK" } });
    expect(res.status()).toBe(400);
    expect(await res.json()).toMatchObject({ detail: "plate must be a string of at most 10 characters" });
  });

  // TC-017 — E7: gateway DECLINED → 402 'payment declined', no row
  test("TC-017 DECLINED charge returns 402 'payment declined' and writes no row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    const txnId = `txn-declined-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "DECLINED", txn_id: txnId });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(402);
      expect(await res.json()).toMatchObject({ detail: "payment declined" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // TC-018 — E8: gateway non-2xx (500) → 502 'payment gateway unavailable', no row
  test("TC-018 gateway HTTP 500 returns 502 'payment gateway unavailable' and writes no row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
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

  // TC-019 — E9: gateway SUCCESS with a whitespace-only txn_id → 502, no row
  test("TC-019 SUCCESS with a whitespace-only txn_id returns 502 and writes no row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "   " });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  // TC-020 — E10: gateway call exceeds PAYMENT_GATEWAY_TIMEOUT_MS → 502, no row
  test("TC-020 gateway timeout returns 502 'payment gateway unavailable' and writes no row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
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

  // TC-022 — E12: reused txn_id differing in vehicle, months AND plate → 409, no new row
  test("TC-022 a reused txn_id differing in vehicle, months and plate returns 409 and writes no new row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `V${dynamicId}`.slice(0, 10);
    const otherPlate = `A${dynamicId}`.slice(0, 10);
    const txnId = `txn-bind-${dynamicId}`;
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

      const second = await api.post("/passes", {
        data: { vehicle: "motorcycle", months: 12, plate: otherPlate },
      });
      expect(second.status()).toBe(409);
      expect(await second.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${otherPlate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-024 — B7/B15: reconciliation masks suspicious[].txn_id as '****' + the LAST 2 chars
  test("TC-024 reconciliation masks a suspicious txn_id as '****' plus its last 2 characters", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plate = `M${dynamicId}`.slice(0, 10);
    const txnId = `txn-mask-${dynamicId}`;
    const masked = `****${String(dynamicId).slice(-2)}`;
    try {
      await db.exec(
        `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, '${plate}', 1500, '${txnId}', 'ACTIVE')`,
      );

      const res = await api.get("/passes/reconciliation");
      expect(res.status()).toBe(200);
      const body = await res.json();
      const suspicious = (body.suspicious as Array<Record<string, unknown>>).filter((s) => s.plate === plate);
      expect(suspicious).toHaveLength(1);
      expect(suspicious[0]).toMatchObject({
        plate,
        txn_id: masked,
        reason: "no successful payment attempt",
      });
      expect(suspicious[0].txn_id).not.toBe(txnId);

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE txn_id = '${txnId}';`);
    }
  });

  // TC-025 — B1: the 409 mismatch still writes the payment_attempts audit row, no new pass
  test("TC-025 the 409 mismatch writes the payment_attempts audit row and no new passes row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `V${dynamicId}`.slice(0, 10);
    const otherPlate = `A${dynamicId}`.slice(0, 10);
    const txnId = `txn-audit-${dynamicId}`;
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

      const second = await api.post("/passes", {
        data: { vehicle: "motorcycle", months: 12, plate: otherPlate },
      });
      expect(second.status()).toBe(409);
      expect(await second.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE txn_id = '${txnId}'`)).toBe(2);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-026 — B7/B15: a longer stored txn_id is masked as '****' + the LAST 2 characters
  test("TC-026 reconciliation masks a longer suspicious txn_id as '****' plus its last 2 characters", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plate = `K${dynamicId}`.slice(0, 10);
    const txnId = `txn-redact-${dynamicId}`;
    const masked = `****${String(dynamicId).slice(-2)}`;
    try {
      await db.exec(
        `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, '${plate}', 1500, '${txnId}', 'ACTIVE')`,
      );

      const res = await api.get("/passes/reconciliation");
      expect(res.status()).toBe(200);
      const body = await res.json();
      const suspicious = (body.suspicious as Array<Record<string, unknown>>).filter((s) => s.plate === plate);
      expect(suspicious).toHaveLength(1);
      expect(suspicious[0]).toMatchObject({
        plate,
        txn_id: masked,
        reason: "no successful payment attempt",
      });
      expect(suspicious[0].txn_id).not.toBe(txnId);

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE txn_id = '${txnId}';`);
    }
  });
// TC-027 — B1: the 409 audit row is written exactly once for this gateway call
  test("TC-027 the 409 writes exactly one audit row for the gateway call and no new passes row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `V${dynamicId}`.slice(0, 10);
    const otherPlate = `A${dynamicId}`.slice(0, 10);
    const txnId = `txn-probe-${dynamicId}`;
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

      const second = await api.post("/passes", {
        data: { vehicle: "motorcycle", months: 12, plate: otherPlate },
      });
      expect(second.status()).toBe(409);
      expect(await second.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE txn_id = '${txnId}'`)).toBe(2);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-028 — B11: the 'duplicate txn_id' branch is unreachable through the schema (see FINDING)
  test("TC-028 reconciliation duplicate-txn_id branch is unreachable: the seed is refused by passes_txn_id_unique", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plateD = `D${dynamicId}`.slice(0, 10);
    const plateE = `E${dynamicId}`.slice(0, 10);
    const txnId = `txn-dup2-${dynamicId}`;
    try {
      await db.exec(
        `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, '${plateD}', 1500, '${txnId}', 'ACTIVE')`,
      );

      await expect(
        db.exec(
          `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, '${plateE}', 1500, '${txnId}', 'ACTIVE')`,
        ),
      ).rejects.toThrow(/passes_txn_id_unique/);

      // The state the CSV wants to seed cannot exist; reconciliation still honours its contract.
      const res = await api.get("/passes/reconciliation");
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toHaveProperty("checked");
      expect(body).toHaveProperty("suspicious");

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-029 — B12: POST /passes stays stateful — one passes row, one audit row, gateway called
  test("TC-029 a successful purchase writes one passes row and one payment_attempts row and calls the gateway", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `S${dynamicId}`.slice(0, 10);
    const txnId = `txn-stateful2-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

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

      expect(
        await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}' AND status = 'ACTIVE'`),
      ).toBe(1);
      expect(await db.value(`SELECT count(*) FROM payment_attempts WHERE txn_id = '${txnId}'`)).toBe(1);
      expect(await mock.received("POST", "/charge")).toHaveLength(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });

  // TC-030 — B14: the ONODE-29 409 binding is in effect on the deployed stack (the behaviour
  // the amended ONODE-12 TC-018 and ONODE-16 TC-014/TC-016 suites now assert)
  test("TC-030 a reused txn_id with a different months value answers 409 on the deployed stack", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `V${dynamicId}`.slice(0, 10);
    const txnId = `txn-amend-${dynamicId}`;
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

      const second = await api.post("/passes", { data: { vehicle: "car", months: 12, plate } });
      expect(second.status()).toBe(409);
      expect(await second.json()).toMatchObject({ detail: "txn_id already used for a different purchase" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}';`,
      );
    }
  });