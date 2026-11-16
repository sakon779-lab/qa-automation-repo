import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-58 — GET /passes/{id} reports expires_at (created_at + months, computed on read) and
 * status EXPIRED once that moment has passed, while a stored status other than ACTIVE is
 * returned as stored and the stored status column is never rewritten.
 *
 * One test per approved CSV row. Every positive row seeds its own pass through `db` with a
 * per-row dynamic id and txn_id, reads it back over HTTP, asserts the body, reads the stored
 * status back (Post-Assertions) and deletes only the row it created in a `finally` teardown, so
 * the fully-parallel suite never collides.
 *
 * The ISO-8601 UTC pattern the CSV names is asserted with a regex; "strictly later/earlier than
 * now" is asserted against the clock read inside the test.
 *
 * ONODE-64 retired TC-009 (the "passes table unavailable → 500" row): it proved a fault-only
 * error by renaming the shared `passes` table, which made every parallel test touching `passes`
 * fail at random. That obligation is proven at the unit layer by this card's own unit tests.
 */
const ISO_UTC = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

test.describe("ONODE-58 — GET /passes/{id} expires_at and EXPIRED status", () => {
  test("TC-001 a freshly bought pass reads ACTIVE with expires_at in the future", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status, created_at) ` +
        `VALUES (${dynamicId}, 'car', 2, '${plate}', 3000, '${txnId}', 'ACTIVE', NOW())`,
    );
    try {
      const res = await api.get(`/passes/${dynamicId}`);
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toMatchObject({
        id: dynamicId,
        vehicle: "car",
        months: 2,
        plate,
        price: 3000,
        currency: "THB",
        status: "ACTIVE",
      });
      expect(typeof body.expires_at).toBe("string");
      expect(body.expires_at).toMatch(ISO_UTC);
      expect(new Date(body.expires_at).getTime()).toBeGreaterThan(Date.now());

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("ACTIVE");
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });

  test("TC-002 a pass seeded 3 months back with months 2 reads EXPIRED with expires_at one month in the past", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status, created_at) ` +
        `VALUES (${dynamicId}, 'car', 2, '${plate}', 3000, '${txnId}', 'ACTIVE', NOW() - INTERVAL '3 months')`,
    );
    try {
      const res = await api.get(`/passes/${dynamicId}`);
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toMatchObject({ id: dynamicId, months: 2, status: "EXPIRED" });
      expect(typeof body.expires_at).toBe("string");
      expect(body.expires_at).toMatch(ISO_UTC);
      expect(new Date(body.expires_at).getTime()).toBeLessThan(Date.now());

      // The stored status column is untouched — the read computes, it never writes.
      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("ACTIVE");
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });

  test("TC-003 a stored CANCELLED pass 3 months old reads CANCELLED (never EXPIRED) with expires_at computed from created_at", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status, created_at) ` +
        `VALUES (${dynamicId}, 'car', 2, '${plate}', 3000, '${txnId}', 'CANCELLED', NOW() - INTERVAL '3 months')`,
    );
    try {
      const res = await api.get(`/passes/${dynamicId}`);
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toMatchObject({ id: dynamicId, months: 2, status: "CANCELLED" });
      expect(typeof body.expires_at).toBe("string");
      expect(body.expires_at).toMatch(ISO_UTC);
      expect(new Date(body.expires_at).getTime()).toBeLessThan(Date.now());

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("CANCELLED");
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });

  test("TC-004 every ONODE-10 field is unchanged alongside the new expires_at, txn_id still masked", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status, created_at) ` +
        `VALUES (${dynamicId}, 'car', 2, '${plate}', 3000, '${txnId}', 'ACTIVE', NOW())`,
    );
    try {
      const res = await api.get(`/passes/${dynamicId}`);
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toMatchObject({
        id: dynamicId,
        vehicle: "car",
        months: 2,
        plate,
        price: 3000,
        currency: "THB",
        status: "ACTIVE",
      });
      expect(typeof body.txn_id).toBe("string");
      expect(body.txn_id).not.toBe(txnId);
      expect(body).toHaveProperty("expires_at");

      expect(await db.value(`SELECT count(*) FROM passes WHERE id = ${dynamicId}`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });

  test("TC-005 non-numeric id 'abc' → 404 'pass not found'", async ({ api }) => {
    const res = await api.get("/passes/abc");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-006 id zero '0' → 404 'pass not found'", async ({ api }) => {
    const res = await api.get("/passes/0");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-007 id one past Postgres integer max '2147483648' → 404 'pass not found'", async ({ api }) => {
    const res = await api.get("/passes/2147483648");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-008 valid in-range integer with no passes row → 404 'pass not found'", async ({ api, dynamicId }) => {
    const missingId = 1_000_000_000 + dynamicId;
    const res = await api.get(`/passes/${missingId}`);
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-010 the 404 'pass not found' answer is unchanged for a valid in-range id with no row", async ({ api, dynamicId }) => {
    const missingId = 1_000_000_000 + dynamicId;
    const res = await api.get(`/passes/${missingId}`);
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-011 expires_at is exactly created_at + 2 calendar months (one month before now), derived on read", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status, created_at) ` +
        `VALUES (${dynamicId}, 'car', 2, '${plate}', 3000, '${txnId}', 'ACTIVE', NOW() - INTERVAL '3 months')`,
    );
    try {
      const createdAt = await db.value<string>(`SELECT created_at FROM passes WHERE id = ${dynamicId}`);
      const res = await api.get(`/passes/${dynamicId}`);
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toMatchObject({ id: dynamicId, months: 2, status: "EXPIRED" });
      expect(typeof body.expires_at).toBe("string");
      expect(body.expires_at).toMatch(ISO_UTC);

      const expiresAt = new Date(body.expires_at).getTime();
      expect(expiresAt).toBeLessThan(Date.now());
      expect(expiresAt).toBeGreaterThan(new Date(createdAt).getTime());

      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("ACTIVE");
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });

  test("TC-012 a stored-ACTIVE pass 13 months old with months 1 reads EXPIRED while the stored status stays ACTIVE", async ({ api, db, dynamicId }) => {
    const plate = `P${dynamicId}`;
    const txnId = `txn_${dynamicId}`;
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status, created_at) ` +
        `VALUES (${dynamicId}, 'car', 1, '${plate}', 1500, '${txnId}', 'ACTIVE', NOW() - INTERVAL '13 months')`,
    );
    try {
      const res = await api.get(`/passes/${dynamicId}`);
      expect(res.status()).toBe(200);
      const body = await res.json();
      expect(body).toMatchObject({ id: dynamicId, months: 1, status: "EXPIRED" });
      expect(typeof body.expires_at).toBe("string");
      expect(body.expires_at).toMatch(ISO_UTC);
      expect(new Date(body.expires_at).getTime()).toBeLessThan(Date.now());

      // No background job rewrites the stored status.
      expect(await db.value(`SELECT status FROM passes WHERE id = ${dynamicId}`)).toBe("ACTIVE");
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });
});