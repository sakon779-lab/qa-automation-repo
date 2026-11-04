import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-12 — POST /passes must reject a SUCCESS charge with an empty/invalid txn_id
 * (SEC-ONODE-8-1). One test per approved CSV row.
 *
 * The gateway is stubbed through `mock.arm('POST', '/charge', …)`; the stub answers only requests
 * carrying this test's X-Request-Id, which `api` sends and the app forwards. Every row asserts the
 * HTTP contract AND the database state (no row on a refusal, exactly one row on a success), then
 * deletes only what it created.
 *
 * FINDING (CSV, all rows): the CSV names the gateway path `/external/payment/charge`. The deployed
 * app calls `/charge` (proven by the passing ONODE-8 suite, which arms `/charge`). Stubbing the
 * CSV's path matches nothing and every positive row would see 502. The rows are automated against
 * the real path `/charge`; the CSV should be corrected.
 *
 * FINDING (CSV, TC-013): the CSV says to send `X-Request-Id: 'req-<dynamic_id>'`. The `mock`
 * fixture scopes stubs to the test's own `requestId`, so a stub armed under `requestId` never
 * matches a forwarded `req-<requestId>` and the app would see no stub (502). The row's intent — the
 * app forwards the incoming X-Request-Id unchanged — is proven by sending the fixture's `requestId`
 * as the header and asserting the gateway recorded exactly that value.
 *
 * FINDING (CSV, TC-014): the CSV's direct INSERT lists a `currency` column; the `passes` table has
 * no such column, so the insert fails on the wrong error. The INSERT here lists only real columns so
 * the rejection is the txn_id CHECK constraint the row is about.
 */

const CHARGE = "/charge";

/** MockServer records a request body as a typed wrapper ({ type, json, rawBytes, … }); unwrap it. */
function recordedJson(body: unknown): unknown {
  if (typeof body === "string") return JSON.parse(body);
  if (body && typeof body === "object" && "json" in body) {
    return (body as { json: unknown }).json;
  }
  return body;
}

test.describe("ONODE-12 — POST /passes rejects an invalid txn_id (SEC-ONODE-8-1)", () => {
  test("TC-001 gateway SUCCESS with txn_id '' → 502 'payment gateway unavailable', no row", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toEqual({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-002 gateway SUCCESS with non-string txn_id 123 → 502 'payment gateway unavailable', no row", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: 123 });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toEqual({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-003 gateway SUCCESS with txn_id 'txn_1' → 201, row persisted and echoed exactly", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "txn_1" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "car",
        months: 1,
        plate,
        price: 1500,
        currency: "THB",
        txn_id: "txn_1",
        status: "ACTIVE",
      });

      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = 'txn_1' AND status = 'ACTIVE'`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-004 txn_id ' txn_1 ' stored as received, plate trimmed, motorcycle 12 months → 5760", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: " txn_1 " });

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
        txn_id: " txn_1 ",
        status: "ACTIVE",
      });

      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = ' txn_1 ' AND status = 'ACTIVE'`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-005 gateway status DECLINED → 402 'payment declined', no row", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "DECLINED", txn_id: "txn_1" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(402);
      expect(await res.json()).toEqual({ detail: "payment declined" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-006 gateway HTTP 500 → 502 'payment gateway unavailable', no row", async ({ api, db, mock, dynamicId }) => {
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

  test("TC-007 vehicle key absent → 400 'vehicle is required', no row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", { data: { months: 1, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toEqual({ detail: "vehicle is required" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-008 vehicle non-string (number 1) → 400 'vehicle must be car or motorcycle', no row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", { data: { vehicle: 1, months: 1, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-009 months key absent → 400 'months is required', no row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toEqual({ detail: "months is required" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-010 months out of range (13) → 400 'months must be an integer from 1 to 12', no row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", months: 13, plate } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-011 whitespace-only plate → 400 'plate is required', no row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: "   " } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toEqual({ detail: "plate is required" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-012 plate longer than 10 chars → 400 'plate must be a string of at most 10 characters', no row", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: "ABCDEFGHIJK" } });
      expect(res.status()).toBe(400);
      expect(await res.json()).toEqual({ detail: "plate must be a string of at most 10 characters" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-013 X-Request-Id is forwarded to the gateway charge call", async ({ api, db, mock, dynamicId, requestId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "txn_1" });

      // The mock fixture scopes stubs to `requestId`; send that same value so the app's forwarded
      // header matches the stub (see FINDING).
      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 1, plate },
        headers: { "X-Request-Id": requestId },
      });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({ plate, txn_id: "txn_1", status: "ACTIVE" });

      const calls = await mock.received("POST", CHARGE);
      expect(calls).toHaveLength(1);
      // MockServer records header names lowercased.
      const headers = calls[0].headers as Record<string, string[]>;
      expect(headers["x-request-id"]).toEqual([requestId]);

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-014 direct INSERT with txn_id '' is rejected by the passes.txn_id CHECK constraint", async ({ db, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await expect(
        db.exec(
          `INSERT INTO passes (vehicle, months, plate, price, txn_id, status) ` +
            `VALUES ('car', 1, '${plate}', 1500, '', 'ACTIVE')`,
        ),
      ).rejects.toThrow(/txn_id/);

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-015 SEC-ONODE-8-1 replay: SUCCESS with txn_id '' → 502, no ACTIVE pass with empty txn_id", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toEqual({ detail: "payment gateway unavailable" });

      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = '' AND status = 'ACTIVE'`,
        ),
      ).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-016 literal txn_id '' yields 502 and the SQL predicate txn_id='' finds no pass", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(502);
      expect(await res.json()).toEqual({ detail: "payment gateway unavailable" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = ''`)).toBe(0);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-017 motorcycle 6 months → price 3240 THB (10% tier)", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "txn_1" });

      const res = await api.post("/passes", { data: { vehicle: "motorcycle", months: 6, plate } });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "motorcycle",
        months: 6,
        plate,
        price: 3240,
        currency: "THB",
        txn_id: "txn_1",
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT price FROM passes WHERE plate = '${plate}'`)).toBe(3240);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-018 gateway is called with the exact charge body {amount, currency, reference}", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "txn_1" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate: `  ${plate}  ` } });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        plate,
        price: 1500,
        currency: "THB",
        txn_id: "txn_1",
        status: "ACTIVE",
      });

      const calls = await mock.received("POST", CHARGE);
      expect(calls).toHaveLength(1);
      expect(recordedJson(calls[0].body)).toEqual({ amount: 1500, currency: "THB", reference: plate });
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-019 gateway SUCCESS with whitespace-only txn_id '   ' → 502, no row", async ({ api, db, mock, dynamicId }) => {
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

  test("TC-020 the passes row is the audit record: txn_id, plate, price, created_at", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "txn_1" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({ plate, price: 1500, txn_id: "txn_1", status: "ACTIVE" });

      expect(
        await db.value(
          `SELECT count(*) FROM passes WHERE plate = '${plate}' AND txn_id = 'txn_1' AND price = 1500 AND created_at IS NOT NULL`,
        ),
      ).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-021 POST /passes is stateful: one row written and GET /passes/{id} reads it back", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "txn_1" });

      const created = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(created.status()).toBe(201);
      const createdBody = await created.json();
      expect(createdBody).toMatchObject({ plate, price: 1500, txn_id: "txn_1", status: "ACTIVE" });

      const read = await api.get(`/passes/${createdBody.id}`);
      expect(read.status()).toBe(200);
      expect(await read.json()).toMatchObject({ plate, price: 1500, txn_id: "txn_1", status: "ACTIVE" });

      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });

  test("TC-022 deployed app uses the injected gateway (1 charge call) and injected DB (row persisted)", async ({ api, db, mock, dynamicId }) => {
    const plate = `P${dynamicId}`.slice(0, 10);
    try {
      await mock.arm("POST", CHARGE, 200, { status: "SUCCESS", txn_id: "txn_1" });

      const res = await api.post("/passes", { data: { vehicle: "car", months: 1, plate } });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({ plate, txn_id: "txn_1", status: "ACTIVE" });

      expect(await mock.received("POST", CHARGE)).toHaveLength(1);
      expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE plate = '${plate}';`);
    }
  });
});