import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-12 — SEC-ONODE-8-1: POST /passes must reject a SUCCESS charge with an
 * empty/invalid txn_id (no pass without a real payment reference).
 *
 * Every row of test_designs/ONODE-12.csv becomes one test. The gateway is stubbed
 * through `mock.arm` (scoped to this test's X-Request-Id, which `api` sends and the
 * app forwards), the DB is read back through `db`, and each test cleans up its own
 * plate in a finally block so the fully-parallel suite never collides.
 *
 * AMENDED by ONODE-29 B4 (TC-018): a reused txn_id whose stored pass differs on any of the
 * four bound fields (vehicle, months, plate, price) now answers 409 'txn_id already used for a
 * different purchase' instead of 200 with the first pass's body.
 *
 * AMENDED by ONODE-32 B18 (TC-021): the GET leg of the stateful read-back returns the MASKED
 * txn_id ('****' + last 2 chars of the stored 'txn_<dynamic_id>XY' = '****XY'), never the clear
 * stored value, while every other field is unchanged.
 */
test.describe("ONODE-12 — reject a SUCCESS charge with an empty/invalid txn_id", () => {
  // TC-001 — gateway SUCCESS with txn_id '' → 502, no row (the SEC-ONODE-8-1 replay)
  test("TC-001 rejects a SUCCESS charge with an empty txn_id", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-002 — gateway SUCCESS with a non-string txn_id (number 123) → 502, no row
  test("TC-002 rejects a SUCCESS charge with a non-string txn_id", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: 123 });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-003 — happy path: real per-case txn_id → 201, persisted and echoed exactly
  test("TC-003 persists and echoes a real txn_id on the happy path", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;
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
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '${txnId}' AND status = 'ACTIVE'`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-004 — txn_id stored exactly as received (whitespace preserved), plate trimmed
  test("TC-004 stores txn_id exactly as received while trimming the plate", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = ` txn_${dynamicId} `;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", {
        data: { vehicle: "motorcycle", months: 12, plate: `  ${plate}  ` },
      });
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
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '${txnId}' AND status = 'ACTIVE'`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-005 — gateway DECLINED → 402, no row
  test("TC-005 returns 402 when the gateway declines the charge", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "DECLINED", txn_id: "txn_1" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(402);
      expect(await res.json()).toMatchObject({ detail: "payment declined" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-006 — gateway HTTP 500 → 502, no row
  test("TC-006 returns 502 when the gateway answers HTTP 500", async ({ api, db, mock, dynamicId }) => {
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

  // TC-007 — vehicle key absent → 400, no gateway call, no row
  test("TC-007 returns 400 when the vehicle key is absent", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      const res = await api.post("/passes", { data: { months: 1, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "vehicle is required" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
      expect(await mock.received("POST", "/charge")).toHaveLength(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-008 — vehicle is a non-string JSON value → 400, no gateway call, no row
  test("TC-008 returns 400 when vehicle is a non-string value", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      const res = await api.post("/passes", { data: { vehicle: 1, months: 1, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "vehicle must be car or motorcycle" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
      expect(await mock.received("POST", "/charge")).toHaveLength(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-009 — months key absent → 400, no gateway call, no row
  test("TC-009 returns 400 when the months key is absent", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "months is required" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
      expect(await mock.received("POST", "/charge")).toHaveLength(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-010 — months out of range (13) → 400, no gateway call, no row
  test("TC-010 returns 400 when months is out of range", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", months: 13, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "months must be an integer from 1 to 12" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
      expect(await mock.received("POST", "/charge")).toHaveLength(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-011 — whitespace-only plate → 400, no gateway call, no row
  test("TC-011 returns 400 when the plate is whitespace-only", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: "   " } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "plate is required" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
      expect(await mock.received("POST", "/charge")).toHaveLength(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-012 — trimmed plate longer than 10 chars → 400, no gateway call, no row
  test("TC-012 returns 400 when the trimmed plate is longer than 10 characters", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: "ABCDEFGHIJK" } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toMatchObject({ detail: "plate must be a string of at most 10 characters" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
      expect(await mock.received("POST", "/charge")).toHaveLength(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-013 — the incoming X-Request-Id is forwarded to the gateway charge call
  test("TC-013 forwards the incoming X-Request-Id to the gateway", async ({ api, db, mock, dynamicId, requestId }) => {
    const plate = `P${dynamicId}`;
    // The stub is armed for this test's requestId; the app must forward that same value
    // to the gateway, so the charge call only matches if the header was passed through.
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "txn_1" });

      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 1, plate },
        headers: { "X-Request-Id": requestId },
      });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({ plate, txn_id: "txn_1", status: "ACTIVE" });

      const received = await mock.received("POST", "/charge");
      expect(received).toHaveLength(1);
      // MockServer records header names in its own casing; match the name case-insensitively.
      const headers = received[0].headers as Record<string, string[]>;
      const forwarded = Object.entries(headers).find(([name]) => name.toLowerCase() === "x-request-id")?.[1];
      expect(forwarded).toContain(requestId);

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-014 — the DB CHECK backstop rejects a direct INSERT with txn_id = ''
  test("TC-014 the DB CHECK rejects a direct INSERT with an empty txn_id", async ({ db, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      await expect(
        db.exec(
          `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) VALUES ('car', 1, '${plate}', 1500, '', 'ACTIVE')`,
        ),
      ).rejects.toThrow(/passes_txn_id_not_blank/);

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-015 — SEC-ONODE-8-1 closing-condition replay: no ACTIVE pass with an empty txn_id
  test("TC-015 the SEC-ONODE-8-1 replay leaves no ACTIVE pass with an empty txn_id", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '' AND status = 'ACTIVE'`,
        ),
      ).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-016 — the literal txn_id fragments are the exact JSON/SQL values asserted on
  test("TC-016 a SUCCESS body with txn_id '' yields 502 and no matching pass", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toMatchObject({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = ''`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-017 — mid-tier discount: motorcycle 6 months -> 3240 THB
  test("TC-017 prices motorcycle 6 months at 3240 THB", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", { data: { vehicle: "motorcycle", months: 6, plate } });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "motorcycle",
        months: 6,
        plate,
        price: 3240,
        currency: "THB",
        txn_id: txnId,
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT price FROM passes WHERE plate = '${plate}'`)).toBe(3240);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-018 — ONODE-29 four-field binding on the idempotent path: a reused txn_id with a
  // DIFFERENT plate answers 409 'txn_id already used for a different purchase' and discloses
  // nothing (no new passes row). AMENDED by ONODE-29 B4 — pre-fix returned 200 with the first
  // pass's body.
  test("TC-018 a reused txn_id with a different plate answers 409 and writes no new row", async ({
    api,
    db,
    mock,
    dynamicId,
  }) => {
    const plate = `P${dynamicId}`;
    const otherPlate = `Q${dynamicId}`;
    const txnId = `txn-${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const first = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: `  ${plate}  ` } });
      expect(first.status()).toBe(201);
      expect(await first.json()).toMatchObject({
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
      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${otherPlate}'`)).toBe(0);
    } finally {
      await db.exec(
        `DELETE FROM payment_attempts WHERE txn_id = '${txnId}'; DELETE FROM passes WHERE txn_id = '${txnId}'`,
      );
    }
  });

  // TC-019 — Layer 2 route guard: whitespace-only txn_id → 502, no row
  test("TC-019 the route guard refuses a whitespace-only txn_id", async ({ api, db, mock, dynamicId }) => {
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

  // TC-020 — the passes row is the audit record
  test("TC-020 the passes row records txn_id, plate, price and created_at", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({ plate, price: 1500, txn_id: txnId, status: "ACTIVE" });

      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '${txnId}' AND price = 1500 AND created_at IS NOT NULL`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-021 — POST /passes is stateful: GET /passes/{id} reads the row back with the MASKED
  // txn_id. AMENDED by ONODE-32 B18 — the GET leg returns '****XY' (last 2 chars of the stored
  // 'txn_<dynamic_id>XY'), never the clear stored value; every other field is unchanged.
  test("TC-021 GET /passes/{id} reads back the pass with the txn_id masked", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}XY`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const created = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(created.status()).toBe(201);
      const createdBody = await created.json();
      expect(createdBody).toMatchObject({ plate, price: 1500, txn_id: txnId, status: "ACTIVE" });

      const fetched = await api.get(`/passes/${createdBody.id}`);
      expect(fetched.status()).toBe(200);
      expect(await fetched.json()).toMatchObject({ plate, price: 1500, txn_id: "****XY", status: "ACTIVE" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-022 — the deployed app uses the injected gateway and the injected database
  test("TC-022 the deployed app reaches MockServer and persists the row", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({ plate, txn_id: txnId, status: "ACTIVE" });

      expect(await mock.received("POST", "/charge")).toHaveLength(1);
      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });

  // TC-023 — ONODE-23 UNIQUE-txn_id interaction: a repeat purchase answers 200, no duplicate row
  test("TC-023 a repeat purchase with the same txn_id answers 200 without a duplicate row", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;
    try {
      await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: txnId });

      const first = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(first.status()).toBe(201);
      expect(await first.json()).toMatchObject({ plate, price: 1500, txn_id: txnId, status: "ACTIVE" });

      const second = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(second.status()).toBe(200);
      expect(await second.json()).toMatchObject({ plate, price: 1500, txn_id: txnId, status: "ACTIVE" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = '${txnId}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}'`);
    }
  });
});