import { test, expect } from "../../resources/playwright/fixtures";

/**
 * ONODE-10 — GET /passes/{id} id validation and read-back.
 *
 * One test per approved CSV row. The negative rows (TC-001..TC-005) prove the id is validated
 * BEFORE any database query: a non-numeric, decimal, or out-of-Postgres-integer-range id must
 * answer 404 'pass not found' rather than a 500 or a leaked DB error. The positive row (TC-006)
 * seeds a pass through `db`, reads it back over HTTP, asserts the stored body, and deletes only
 * the row it created in a `finally` teardown.
 */

test.describe("ONODE-10 — GET /passes/{id} id validation and read-back", () => {
  test("TC-001 non-numeric id 'abc' → 404 'pass not found' (validated before any DB query)", async ({ api }) => {
    const res = await api.get("/passes/abc");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-002 decimal id '1.5' → 404 'pass not found' (not a base-10 positive integer)", async ({ api }) => {
    const res = await api.get("/passes/1.5");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-003 id one past Postgres integer max '2147483648' → 404 'pass not found' without querying the DB", async ({ api }) => {
    const res = await api.get("/passes/2147483648");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-004 id far out of Postgres integer range '99999999999' → 404 'pass not found' without leaking a DB error", async ({ api }) => {
    const res = await api.get("/passes/99999999999");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-005 max in-range integer '2147483647' with no row → 404 'pass not found'", async ({ api }) => {
    const res = await api.get("/passes/2147483647");
    expect(res.status()).toBe(404);
    expect(await res.json()).toEqual({ detail: "pass not found" });
  });

  test("TC-006 existing in-range id → 200 with the stored pass body", async ({ api, db, dynamicId }) => {
    await db.exec(
      `INSERT INTO passes (id, vehicle, months, plate, price, txn_id, status) ` +
        `VALUES (${dynamicId}, 'car', 3, 'ABC123', 4500, 'txn_1', 'ACTIVE')`,
    );
    try {
      const res = await api.get(`/passes/${dynamicId}`);
      expect(res.status()).toBe(200);
      expect(await res.json()).toEqual({
        id: dynamicId,
        vehicle: "car",
        months: 3,
        plate: "ABC123",
        price: 4500,
        currency: "THB",
        txn_id: "txn_1",
        status: "ACTIVE",
      });

      expect(await db.value(`SELECT count(*) FROM passes WHERE id = ${dynamicId}`)).toBe(1);
    } finally {
      await db.exec(`DELETE FROM passes WHERE id = ${dynamicId};`);
    }
  });
});