import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-29 — POST /passes txn_id binding (SEC-ONODE-23-1) and reconciliation masking.
 *
 * A reused gateway txn_id is only idempotent when the request matches the stored pass on all
 * four bound fields (vehicle, months, plate, price). Any mismatch answers 409
 * 'txn_id already used for a different purchase' and writes no new passes row. The plate is
 * trimmed before the comparison (B2) but the comparison is case-sensitive (B4).
 * GET /passes/reconciliation masks suspicious[].txn_id as a FIXED '****' prefix plus the LAST 2
 * characters of the stored value (B7).
 *
 * One test per approved CSV row, titled with its CaseID. The gateway is stubbed through
 * `mock.arm` (scoped to this test's X-Request-Id, which `api` sends and the app forwards), the
 * DB is read back through `db`, and each test cleans up only its own rows in a finally block so
 * the fully-parallel suite never collides.
 *
 * AMENDED by ONODE-42 B1: GET /passes/reconciliation now requires the `X-Reconciliation-Token`
 * header equal to RECONCILIATION_TOKEN; without it the endpoint answers 401. TC-024 and TC-026
 * therefore send the token on their reconciliation call.
 */
const RECONCILIATION_TOKEN = "qa-reconciliation-token";

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

  // TC-024 — B7: reconciliation masks a stored txn_id as a FIXED '****' + the LAST 2 characters
  // AMENDED by ONODE-42 B1: the request carries X-Reconciliation-Token.
  test("TC-024 reconciliation masks a suspicious txn_id as '****' plus its last 2 characters", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plate = `M${dynamicId}`.slice(0, 10);
    const txnId = `txn-mask-${dynamicId}XY`;
    try {
      await db.exec(
        `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, '${plate}', 1500, '${txnId}', 'ACTIVE')`,
      );

      const res = await api.get("/passes/reconciliation", {
        headers: { "X-Reconciliation-Token": RECONCILIATION_TOKEN },
      });
      expect(res.status()).toBe(200);
      const body = await res.json();
      const suspicious = (body.suspicious as Array<Record<string, unknown>>).filter((s) => s.plate === plate);
      expect(suspicious).toHaveLength(1);
      expect(suspicious[0]).toMatchObject({
        plate,
        txn_id: "****XY",
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

  // TC-026 — B7: a longer stored txn_id is masked as a FIXED '****' + the LAST 2 characters
  // AMENDED by ONODE-42 B1: the request carries X-Reconciliation-Token.
  test("TC-026 reconciliation masks a longer suspicious txn_id as '****' plus its last 2 characters", async ({
    api,
    db,
    dynamicId,
  }) => {
    const plate = `K${dynamicId}`.slice(0, 10);
    const txnId = `txn-redact-${dynamicId}AB`;
    try {
      await db.exec(
        `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, '${plate}', 1500, '${txnId}', 'ACTIVE')`,
      );

      const res = await api.get("/passes/reconciliation", {
        headers: { "X-Reconciliation-Token": RECONCILIATION_TOKEN },
      });
      expect(res.status()).toBe(200);
      const body = await res.json();
      const suspicious = (body.suspicious as Array<Record<string, unknown>>).filter((s) => s.plate === plate);
      expect(suspicious).toHaveLength(1);
      expect(suspicious[0]).toMatchObject({
        plate,
        txn_id: "****AB",
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
});