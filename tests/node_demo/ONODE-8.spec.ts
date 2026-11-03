import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-8 — buy a monthly pass: POST /passes (prices via quotePass, charges the external
 * payment gateway, persists one row in `passes`) and GET /passes/{id}.
 *
 * One test per approved CSV row. Stateful rows arm the gateway stub with `mock.arm` (scoped to
 * this test's X-Request-Id, which `api` sends and the app forwards to /charge), assert the DB
 * post-condition through `db`, and delete only the rows they created in a `finally` teardown.
 *
 * FINDING (CSV, TC-004/005/006/007/010/011): the CSV's post-assertion
 * `SELECT count(*) FROM passes WHERE plate = 'AB1234'` -> 0 is not parallel-safe: the positive
 * rows TC-001/TC-014/TC-016 also buy plate 'AB1234', so under `fullyParallel` those rows are
 * live when a negative row runs and the count is 3, not 0. The rows' intent — "this rejected
 * request wrote no row" — is preserved here by submitting a plate unique to the test
 * (`N<dynamicId>`, <= 10 chars) and asserting no row exists for THAT plate. The CSV should be
 * corrected to use a per-test plate for the negative rows.
 *
 * FINDING (CSV, TC-013): the CSV says to send `X-Request-Id: 'req-<dynamic_id>'`. The `mock`
 * fixture scopes stubs to the test's own `requestId`, so a stub armed under `requestId` never
 * matches a forwarded `req-<requestId>` and the app would see no stub (502). The row's intent —
 * the app forwards the incoming X-Request-Id unchanged — is proven by sending the fixture's
 * `requestId` as the header and asserting the gateway recorded exactly that value.
 */

/** MockServer records a request body as a typed wrapper ({ type, json, rawBytes, ... }); unwrap it. */
function recordedJson(body: unknown): unknown {
  if (typeof body === "string") return JSON.parse(body);
  if (body && typeof body === "object" && "json" in body) {
    return (body as { json: unknown }).json;
  }
  return body;
}

test.describe("ONODE-8 — buy a monthly pass (POST /passes, GET /passes/{id})", () => {
  test("TC-001 car 6 months, gateway SUCCESS → 201 price 8100 ACTIVE and one row persisted", async ({ api, db, mock }) => {
    await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "txn_1" });
    try {
      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 6, plate: "AB1234" },
      });
      expect(res.status()).toBe(201);
      const body = await res.json();
      expect(body).toMatchObject({
        vehicle: "car",
        months: 6,
        plate: "AB1234",
        price: 8100,
        currency: "THB",
        txn_id: "txn_1",
        status: "ACTIVE",
      });
      expect(typeof body.id).toBe("number");

      expect(
        await db.value(`SELECT count(*) FROM passes WHERE plate = 'AB1234' AND txn_id = 'txn_1'`),
      ).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE txn_id = 'txn_1'`);
    }
  });

  test("TC-002 motorcycle 12 months → 201 price 5760 and gateway charged amount 5760 THB ref MC99", async ({ api, db, mock }) => {
    await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "txn_2" });
    try {
      const res = await api.post("/passes", {
        data: { vehicle: "motorcycle", months: 12, plate: "MC99" },
      });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "motorcycle",
        months: 12,
        plate: "MC99",
        price: 5760,
        currency: "THB",
        txn_id: "txn_2",
        status: "ACTIVE",
      });

      const charged = await mock.received("POST", "/charge");
      expect(charged).toHaveLength(1);
      expect(recordedJson(charged[0].body)).toEqual({
        amount: 5760,
        currency: "THB",
        reference: "MC99",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = 'txn_2'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE txn_id = 'txn_2'`);
    }
  });

  test("TC-003 plate '  AB1  ' is trimmed → 201 plate AB1 price 1500 and stored trimmed", async ({ api, db, mock }) => {
    await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "txn_3" });
    try {
      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 1, plate: "  AB1  " },
      });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({
        vehicle: "car",
        months: 1,
        plate: "AB1",
        price: 1500,
        currency: "THB",
        txn_id: "txn_3",
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT plate FROM passes WHERE txn_id = 'txn_3'`)).toBe("AB1");
    } finally {
      await db.exec(`DELETE FROM passes WHERE txn_id = 'txn_3'`);
    }
  });

  test("TC-004 absent vehicle → 400 'vehicle is required' and no row", async ({ api, db, dynamicId }) => {
    // Per-test plate (see FINDING): the CSV's shared 'AB1234' collides with the positive rows.
    const plate = `N${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", {
      data: { months: 6, plate },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle is required" });

    expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
  });

  test("TC-005 vehicle 'Car' (wrong case) → 400 'vehicle must be car or motorcycle' and no row", async ({ api, db, dynamicId }) => {
    const plate = `N${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", {
      data: { vehicle: "Car", months: 6, plate },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });

    expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
  });

  test("TC-006 absent months → 400 'months is required' and no row", async ({ api, db, dynamicId }) => {
    const plate = `N${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", {
      data: { vehicle: "car", plate },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months is required" });

    expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
  });

  test("TC-007 months 13 → 400 'months must be an integer from 1 to 12' and no row", async ({ api, db, dynamicId }) => {
    const plate = `N${dynamicId}`.slice(0, 10);
    const res = await api.post("/passes", {
      data: { vehicle: "car", months: 13, plate },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "months must be an integer from 1 to 12" });

    expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
  });

  test("TC-008 whitespace-only plate → 400 'plate is required' and no row", async ({ api, db }) => {
    const res = await api.post("/passes", {
      data: { vehicle: "car", months: 6, plate: "   " },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "plate is required" });

    expect(await db.value(`SELECT count(*) FROM passes WHERE plate = ''`)).toBe(0);
  });

  test("TC-009 plate 11 chars after trim → 400 'plate must be a string of at most 10 characters' and no row", async ({ api, db }) => {
    const res = await api.post("/passes", {
      data: { vehicle: "car", months: 6, plate: "ABCDEFGHIJK" },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "plate must be a string of at most 10 characters" });

    expect(await db.value(`SELECT count(*) FROM passes WHERE plate = 'ABCDEFGHIJK'`)).toBe(0);
  });

  test("TC-010 gateway DECLINED → 402 'payment declined' and no row", async ({ api, db, mock, dynamicId }) => {
    const plate = `N${dynamicId}`.slice(0, 10);
    await mock.arm("POST", "/charge", 200, { status: "DECLINED" });
    const res = await api.post("/passes", {
      data: { vehicle: "car", months: 6, plate },
    });
    expect(res.status()).toBe(402);
    expect(await res.json()).toEqual({ detail: "payment declined" });

    expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
  });

  test("TC-011 gateway 500 → 502 'payment gateway unavailable' and no row", async ({ api, db, mock, dynamicId }) => {
    const plate = `N${dynamicId}`.slice(0, 10);
    await mock.arm("POST", "/charge", 500, { error: "internal" });
    const res = await api.post("/passes", {
      data: { vehicle: "car", months: 6, plate },
    });
    expect(res.status()).toBe(502);
    expect(await res.json()).toEqual({ detail: "payment gateway unavailable" });

    expect(await db.value(`SELECT count(*) FROM passes WHERE plate = '${plate}'`)).toBe(0);
  });

  test("TC-012 GET /passes/{id} for a non-existent id → 404 'pass not found'", async ({ api, dynamicId }) => {
    // A positive integer id that cannot exist: derived from the unique dynamicId, far above any
    // row this suite creates, and never inserted by this test.
    const missingId = 1_000_000_000 + dynamicId;
    const res = await api.get(`/passes/${missingId}`);
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-013 X-Request-Id is forwarded to the gateway unchanged", async ({ api, db, mock, requestId }) => {
    // The mock fixture scopes stubs to `requestId`; send that same value so the app's forwarded
    // header matches the stub (see FINDING).
    await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "txn_5" });
    try {
      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 6, plate: "AB1234" },
        headers: { "X-Request-Id": requestId },
      });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({ txn_id: "txn_5", status: "ACTIVE" });

      const charged = await mock.received("POST", "/charge");
      expect(charged).toHaveLength(1);
      // MockServer records header names lowercased.
      const headers = charged[0].headers as Record<string, string[]>;
      expect(headers["x-request-id"]).toEqual([requestId]);

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = 'txn_5'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE txn_id = 'txn_5'`);
    }
  });

  test("TC-014 GET /passes/{id} returns the same body as the POST 201", async ({ api, db, mock }) => {
    await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "txn_6" });
    try {
      const created = await api.post("/passes", {
        data: { vehicle: "car", months: 6, plate: "AB1234" },
      });
      expect(created.status()).toBe(201);
      const createdBody = await created.json();
      expect(createdBody).toMatchObject({
        vehicle: "car",
        months: 6,
        plate: "AB1234",
        price: 8100,
        currency: "THB",
        txn_id: "txn_6",
        status: "ACTIVE",
      });

      const fetched = await api.get(`/passes/${createdBody.id}`);
      expect(fetched.status()).toBe(200);
      expect(await fetched.json()).toEqual(createdBody);

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = 'txn_6'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE txn_id = 'txn_6'`);
    }
  });

  test("TC-015 vehicle validated first → 400 vehicle error, gateway never called, no row", async ({ api, db, mock }) => {
    await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "txn_7" });
    const res = await api.post("/passes", {
      data: { vehicle: "truck", months: 99, plate: "ABCDEFGHIJK" },
    });
    expect(res.status()).toBe(400);
    expect(await res.json()).toEqual({ detail: "vehicle must be car or motorcycle" });

    expect(await mock.received("POST", "/charge")).toHaveLength(0);
    expect(await db.value(`SELECT count(*) FROM passes WHERE plate = 'ABCDEFGHIJK'`)).toBe(0);
  });

  test("TC-016 deployed app uses real Postgres and real gateway: row persisted AND gateway reached", async ({ api, db, mock }) => {
    await mock.arm("POST", "/charge", 200, { status: "SUCCESS", txn_id: "txn_8" });
    try {
      const res = await api.post("/passes", {
        data: { vehicle: "car", months: 6, plate: "AB1234" },
      });
      expect(res.status()).toBe(201);
      expect(await res.json()).toMatchObject({ txn_id: "txn_8", status: "ACTIVE" });

      const charged = await mock.received("POST", "/charge");
      expect(charged).toHaveLength(1);
      expect(recordedJson(charged[0].body)).toEqual({
        amount: 8100,
        currency: "THB",
        reference: "AB1234",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE txn_id = 'txn_8'`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE txn_id = 'txn_8'`);
    }
  });
});